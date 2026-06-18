--Etap 8 - Implementacja niedeklaratywnych mechanizmow sprawdzania
--poprawnosci danych. System wynajmu miejskich jednosladow.

--Skrypt tworzy 7 wyzwalaczy (TR_*) oraz 3 procedury skladowane (usp_*)
--zaprojektowane w etapie 7. Idempotentny - przed utworzeniem kazdego
--obiektu wykonywany jest DROP IF EXISTS, mozna uruchamiac wielokrotnie.
--
--Wymaganie wstepne: baza WynajemJednosladow utworzona skryptem z etapu 6

USE WynajemJednosladow;
GO

--WYZWALACZE

--TR_Pojazd_AIU_Pojemnosc (ZPB4)
--Po wstawieniu / zmianie id_stacji pojazdu sprawdza, czy nie zostala
--przekroczona pojemnosc stacji.
IF OBJECT_ID('dbo.TR_Pojazd_AIU_Pojemnosc', 'TR') IS NOT NULL
	DROP TRIGGER dbo.TR_Pojazd_AIU_Pojemnosc;
GO

CREATE TRIGGER TR_Pojazd_AIU_Pojemnosc
ON dbo.Pojazd
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;

	IF NOT UPDATE(id_stacji) AND NOT EXISTS (SELECT 1 FROM inserted)
		RETURN;

	IF EXISTS (
		SELECT 1
		FROM (
			SELECT id_stacji FROM inserted WHERE id_stacji IS NOT NULL
		) i
		JOIN dbo.Stacja s ON s.id_stacji = i.id_stacji
		CROSS APPLY (
			SELECT COUNT(*) AS cnt
			FROM dbo.Pojazd p
			WHERE p.id_stacji = i.id_stacji
		) c
		WHERE c.cnt > s.pojemnosc
	)
	BEGIN
		ROLLBACK TRANSACTION;
		THROW 50001, 'Przekroczono pojemnosc stacji', 1;
	END
END
GO

--TR_Wypozyczenie_AI_RozpoczeciePojazd (ZPB1 - czesc)
--Po wstawieniu wypozyczenia: sprawdza dostepnosc pojazdu, ustawia
--status = 'wypozyczony' oraz id_stacji = NULL (pojazd wyjezdza ze stacji).

IF OBJECT_ID('dbo.TR_Wypozyczenie_AI_RozpoczeciePojazd', 'TR') IS NOT NULL
	DROP TRIGGER dbo.TR_Wypozyczenie_AI_RozpoczeciePojazd;
GO

CREATE TRIGGER TR_Wypozyczenie_AI_RozpoczeciePojazd
ON dbo.Wypozyczenie
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
		SELECT 1
		FROM inserted i
		JOIN dbo.Pojazd p ON p.id_pojazdu = i.id_pojazdu
		WHERE p.status <> N'dostepny'
	)
	BEGIN
		ROLLBACK TRANSACTION;
		THROW 50002, 'Pojazd nie jest dostepny do wypozyczenia', 1;
	END

	UPDATE p
	SET p.status = N'wypozyczony',
	    p.id_stacji = NULL
	FROM dbo.Pojazd p
	JOIN inserted i ON i.id_pojazdu = p.id_pojazdu;
END
GO

--TR_Wypozyczenie_AU_ZakonczeniePojazd (ZPB1, ZPB8 - czesc)
--Po wypelnieniu data_zakonczenia: aktualizuje status i lokalizacje pojazdu.

IF OBJECT_ID('dbo.TR_Wypozyczenie_AU_ZakonczeniePojazd', 'TR') IS NOT NULL
	DROP TRIGGER dbo.TR_Wypozyczenie_AU_ZakonczeniePojazd;
GO

CREATE TRIGGER TR_Wypozyczenie_AU_ZakonczeniePojazd
ON dbo.Wypozyczenie
AFTER UPDATE
AS
BEGIN
	SET NOCOUNT ON;

	IF NOT UPDATE(data_zakonczenia)
		RETURN;

	--Wiersze swiezo zakonczone (przejscie NULL -> NOT NULL)
	;WITH konczone AS (
		SELECT i.id_pojazdu, i.id_stacji_koncowej
		FROM inserted i
		JOIN deleted  d ON d.id_wypozyczenia = i.id_wypozyczenia
		WHERE i.data_zakonczenia IS NOT NULL
		  AND d.data_zakonczenia IS NULL
	)
	UPDATE p
	SET p.status = CASE WHEN k.id_stacji_koncowej IS NOT NULL
						THEN N'dostepny'
						ELSE N'do zadokowania'
				   END,
	    p.id_stacji = k.id_stacji_koncowej
	FROM dbo.Pojazd p
	JOIN konczone k ON k.id_pojazdu = p.id_pojazdu;
END
GO

--TR_Wypozyczenie_AI_SaldoCennik (ZPB5 - rozpoczecie, ZPB7)
--Przy starcie wypozyczenia sprawdza saldo > 0 oraz dopasowanie cennika.

IF OBJECT_ID('dbo.TR_Wypozyczenie_AI_SaldoCennik', 'TR') IS NOT NULL
	DROP TRIGGER dbo.TR_Wypozyczenie_AI_SaldoCennik;
GO

CREATE TRIGGER TR_Wypozyczenie_AI_SaldoCennik
ON dbo.Wypozyczenie
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
		SELECT 1
		FROM inserted i
		JOIN dbo.Uzytkownik u ON u.id_uzytkownika = i.id_uzytkownika
		WHERE u.saldo <= 0
	)
	BEGIN
		ROLLBACK TRANSACTION;
		THROW 50003, 'Saldo musi byc dodatnie aby rozpoczac wypozyczenie', 1;
	END

	IF EXISTS (
		SELECT 1
		FROM inserted i
		JOIN dbo.Pojazd  p ON p.id_pojazdu = i.id_pojazdu
		JOIN dbo.Cennik  c ON c.id_cennika = i.id_cennika
		WHERE NOT (
			c.typ_pojazdu = p.typ
			AND c.data_od <= i.data_rozpoczecia
			AND (c.data_do IS NULL OR c.data_do >= i.data_rozpoczecia)
		)
	)
	BEGIN
		ROLLBACK TRANSACTION;
		THROW 50004, 'Cennik nie obowiazuje dla tego pojazdu/daty', 1;
	END
END
GO

--TR_Wypozyczenie_AU_SaldoOplata (ZPB5 - zakonczenie)
--Po wypelnieniu kolumny oplata odejmuje ja od salda uzytkownika.

IF OBJECT_ID('dbo.TR_Wypozyczenie_AU_SaldoOplata', 'TR') IS NOT NULL
	DROP TRIGGER dbo.TR_Wypozyczenie_AU_SaldoOplata;
GO

CREATE TRIGGER TR_Wypozyczenie_AU_SaldoOplata
ON dbo.Wypozyczenie
AFTER UPDATE
AS
BEGIN
	SET NOCOUNT ON;

	IF NOT UPDATE(oplata)
		RETURN;

	--Sumy oplat dopisanych w tym DML (przejscie NULL -> NOT NULL),
	--zgrupowane po uzytkowniku
	DECLARE @sumy TABLE (
		id_uzytkownika	INT				PRIMARY KEY,
		oplata_suma		DECIMAL(10,2)	NOT NULL
	);

	INSERT INTO @sumy (id_uzytkownika, oplata_suma)
	SELECT i.id_uzytkownika, SUM(i.oplata)
	FROM inserted i
	JOIN deleted  d ON d.id_wypozyczenia = i.id_wypozyczenia
	WHERE i.oplata IS NOT NULL
	  AND d.oplata IS NULL
	GROUP BY i.id_uzytkownika;

	IF NOT EXISTS (SELECT 1 FROM @sumy)
		RETURN;

	--Wczesniejsze sprawdzenie: czy saldo wystarczy (czytelny blad
	--zamiast naruszenia CK_Uzytkownik_saldo)
	IF EXISTS (
		SELECT 1
		FROM @sumy s
		JOIN dbo.Uzytkownik u ON u.id_uzytkownika = s.id_uzytkownika
		WHERE u.saldo < s.oplata_suma
	)
	BEGIN
		ROLLBACK TRANSACTION;
		THROW 50005, 'Niewystarczajace saldo do pokrycia oplaty - wymagane doladowanie przed zakonczeniem wypozyczenia', 1;
	END

	UPDATE u
	SET u.saldo = u.saldo - s.oplata_suma
	FROM dbo.Uzytkownik u
	JOIN @sumy s ON s.id_uzytkownika = u.id_uzytkownika;
END
GO

--TR_Cennik_AIU_Nakladanie (ZPB6 - czesc)
--Zakresy obowiazywania cennika dla tego samego typ_pojazdu
--nie moga sie na siebie nakladac.

IF OBJECT_ID('dbo.TR_Cennik_AIU_Nakladanie', 'TR') IS NOT NULL
	DROP TRIGGER dbo.TR_Cennik_AIU_Nakladanie;
GO

CREATE TRIGGER TR_Cennik_AIU_Nakladanie
ON dbo.Cennik
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
		SELECT 1
		FROM inserted i
		JOIN dbo.Cennik c
		  ON c.typ_pojazdu = i.typ_pojazdu
		 AND c.id_cennika <> i.id_cennika
		WHERE i.data_od <= COALESCE(c.data_do, '9999-12-31')
		  AND COALESCE(i.data_do, '9999-12-31') >= c.data_od
	)
	BEGIN
		ROLLBACK TRANSACTION;
		THROW 50006, 'Zakres obowiazywania cennika naklada sie z innym cennikiem tego samego typu', 1;
	END
END
GO

--TR_Doladowanie_AI_Saldo (ZPB9)
--Po wstawieniu doladowania zwieksza saldo uzytkownika o sume kwot.

IF OBJECT_ID('dbo.TR_Doladowanie_AI_Saldo', 'TR') IS NOT NULL
	DROP TRIGGER dbo.TR_Doladowanie_AI_Saldo;
GO

CREATE TRIGGER TR_Doladowanie_AI_Saldo
ON dbo.Doladowanie
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;

	UPDATE u
	SET u.saldo = u.saldo + s.suma_kwot
	FROM dbo.Uzytkownik u
	JOIN (
		SELECT id_uzytkownika, SUM(kwota) AS suma_kwot
		FROM inserted
		GROUP BY id_uzytkownika
	) s ON s.id_uzytkownika = u.id_uzytkownika;
END
GO

--PROCEDURY SKLADOWANE

--usp_RozpocznijWypozyczenie
--Tworzy nowe wypozyczenie. Triggery TR_Wypozyczenie_AI_SaldoCennik
--oraz TR_Wypozyczenie_AI_RozpoczeciePojazd uruchamiaja sie automatycznie
--i pilnuja regul (saldo, cennik, dostepnosc pojazdu).
--Zwraca id_wypozyczenia (SCOPE_IDENTITY).

IF OBJECT_ID('dbo.usp_RozpocznijWypozyczenie', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_RozpocznijWypozyczenie;
GO

CREATE PROCEDURE usp_RozpocznijWypozyczenie
	@id_uzytkownika			INT,
	@id_pojazdu				INT,
	@id_cennika				INT,
	@id_stacji_startowej	INT,
	@data_rozpoczecia		DATETIME2(0) = NULL,
	@id_wypozyczenia		INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	IF @data_rozpoczecia IS NULL
		SET @data_rozpoczecia = SYSDATETIME();

	BEGIN TRY
		BEGIN TRANSACTION;

		INSERT INTO dbo.Wypozyczenie (
			data_rozpoczecia,
			id_uzytkownika,
			id_pojazdu,
			id_cennika,
			id_stacji_startowej
		)
		VALUES (
			@data_rozpoczecia,
			@id_uzytkownika,
			@id_pojazdu,
			@id_cennika,
			@id_stacji_startowej
		);

		SET @id_wypozyczenia = CAST(SCOPE_IDENTITY() AS INT);

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF XACT_STATE() <> 0
			ROLLBACK TRANSACTION;
		THROW;
	END CATCH
END
GO

--usp_ZakonczWypozyczenie
--Konczy wypozyczenie: oblicza oplate (minuta rozpoczeta = pelna minuta,
--zaokraglenie w gore), zapisuje miejsce zwrotu. Triggery
--TR_Wypozyczenie_AU_ZakonczeniePojazd i TR_Wypozyczenie_AU_SaldoOplata
--zadbaja o status pojazdu i odjecie oplaty od salda.
--Zwraca obliczona oplate.

IF OBJECT_ID('dbo.usp_ZakonczWypozyczenie', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_ZakonczWypozyczenie;
GO

CREATE PROCEDURE usp_ZakonczWypozyczenie
	@id_wypozyczenia		INT,
	@id_stacji_koncowej		INT				= NULL,
	@koncowa_szerokosc		DECIMAL(9,6)	= NULL,
	@koncowa_dlugosc		DECIMAL(9,6)	= NULL,
	@data_zakonczenia		DATETIME2(0)	= NULL,
	@oplata					DECIMAL(10,2) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	IF @data_zakonczenia IS NULL
		SET @data_zakonczenia = SYSDATETIME();

	BEGIN TRY
		BEGIN TRANSACTION;

		DECLARE @data_rozpoczecia	DATETIME2(0);
		DECLARE @stawka				DECIMAL(10,2);
		DECLARE @minuty				INT;
		DECLARE @sekundy_reszta		INT;

		SELECT @data_rozpoczecia = w.data_rozpoczecia,
		       @stawka           = c.stawka_za_minute
		FROM dbo.Wypozyczenie w
		JOIN dbo.Cennik       c ON c.id_cennika = w.id_cennika
		WHERE w.id_wypozyczenia = @id_wypozyczenia
		  AND w.data_zakonczenia IS NULL;

		IF @data_rozpoczecia IS NULL
		BEGIN
			ROLLBACK TRANSACTION;
			THROW 50007, 'Wypozyczenie nie istnieje albo zostalo juz zakonczone', 1;
		END

		--Naliczanie: minuta rozpoczeta = minuta oplacona (zaokraglenie w gore)
		SET @minuty         = DATEDIFF(MINUTE, @data_rozpoczecia, @data_zakonczenia);
		SET @sekundy_reszta = DATEDIFF(SECOND, DATEADD(MINUTE, @minuty, @data_rozpoczecia), @data_zakonczenia);
		IF @sekundy_reszta > 0
			SET @minuty = @minuty + 1;
		IF @minuty < 1
			SET @minuty = 1;

		SET @oplata = @minuty * @stawka;

		UPDATE dbo.Wypozyczenie
		SET data_zakonczenia	= @data_zakonczenia,
		    oplata				= @oplata,
		    id_stacji_koncowej	= @id_stacji_koncowej,
		    koncowa_szerokosc	= @koncowa_szerokosc,
		    koncowa_dlugosc		= @koncowa_dlugosc
		WHERE id_wypozyczenia = @id_wypozyczenia;

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF XACT_STATE() <> 0
			ROLLBACK TRANSACTION;
		THROW;
	END CATCH
END
GO

--usp_Doladuj
--Dodaje doladowanie dla uzytkownika. Trigger TR_Doladowanie_AI_Saldo
--zwiekszy saldo (atomowo w tej samej transakcji).
--Zwraca nowe saldo uzytkownika.

IF OBJECT_ID('dbo.usp_Doladuj', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_Doladuj;
GO

CREATE PROCEDURE usp_Doladuj
	@id_uzytkownika	INT,
	@kwota			DECIMAL(10,2),
	@data			DATETIME2(0) = NULL,
	@nowe_saldo		DECIMAL(10,2) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	IF @data IS NULL
		SET @data = SYSDATETIME();

	BEGIN TRY
		BEGIN TRANSACTION;

		INSERT INTO dbo.Doladowanie (kwota, data, id_uzytkownika)
		VALUES (@kwota, @data, @id_uzytkownika);

		SELECT @nowe_saldo = saldo
		FROM dbo.Uzytkownik
		WHERE id_uzytkownika = @id_uzytkownika;

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF XACT_STATE() <> 0
			ROLLBACK TRANSACTION;
		THROW;
	END CATCH
END
GO

PRINT 'Etap 8: 7 wyzwalaczy i 3 procedury skladowane utworzone pomyslnie.';
GO

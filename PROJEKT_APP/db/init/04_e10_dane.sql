--Etap 10 - Testowanie bazy danych.
--System wynajmu miejskich jednosladow.
--
--Skrypt wykonuje dwa zadania etapu 10:
--1. Wprowadza przykladowe, pseudorzeczywiste dane (uzytkownicy,
--	   stacje, pojazdy, cenniki, doladowania, wypozyczenia).
--2. Tworzy procedury testujace (usp_Test*) sprawdzajace czy reguly
--	   biznesowe (ZPB1, ZPB4..ZPB9 z e05 -> triggery z e08) faktycznie
--	   dzialaja, oraz uruchamia procedure usp_TestyWszystkie, ktora
--	   wyswietla podsumowanie PASS/FAIL.
--
--Skrypt idempotentny
--
--Wymagania wstepne: baza WynajemJednosladow (e06) + triggery i procedury
--operacyjne z e08 + skrypt z e09 (warstwa odczytowa + indeksy)
--
--Uwaga: do wprowadzania danych NIE wylaczamy zadnych triggerow - wszystkie
--operacje ida przez procedury z e08 (`usp_Doladuj`/`usp_RozpocznijWypozyczenie`
--/`usp_ZakonczWypozyczenie`), wiec triggery dzialaja jak w normalnej pracy
--aplikacji i jednoczesnie sa "po cichu" sprawdzane.

USE WynajemJednosladow;
GO

--SEKCJA A - czyszczenie poprzednich danych (idempotentnosc)

--Kolejnosc istotna ze wzgledu na FK. Wszystkie triggery z e08 sa AFTER
--INSERT/UPDATE (brak na DELETE), wiec DELETE jest bezpieczny.

DELETE FROM dbo.Doladowanie;
DELETE FROM dbo.Wypozyczenie;
DELETE FROM dbo.Pojazd;
DELETE FROM dbo.Cennik;
DELETE FROM dbo.Stacja;
DELETE FROM dbo.Uzytkownik;
GO

--Reset IDENTITY - kolejne INSERT-y zaczna od id=1.
--UWAGA: 'RESEED, 0' robimy tylko dla tabel, ktore juz mialy jakies wiersze.
--Na swiezo utworzonej tabeli z e06 (nigdy nie inserted) RESEED, 0 spowodowalby,
--ze pierwszy INSERT dostaje id=0 zamiast id=1 (rozne zachowanie tego polecenia
--w zaleznosci od historii tabeli - sys.identity_columns.last_value IS NULL
--oznacza ze tabela jest "swieza").
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.Uzytkownik'))  IS NOT NULL
	DBCC CHECKIDENT ('dbo.Uzytkownik',  RESEED, 0) WITH NO_INFOMSGS;
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.Stacja'))      IS NOT NULL
	DBCC CHECKIDENT ('dbo.Stacja',      RESEED, 0) WITH NO_INFOMSGS;
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.Pojazd'))      IS NOT NULL
	DBCC CHECKIDENT ('dbo.Pojazd',      RESEED, 0) WITH NO_INFOMSGS;
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.Cennik'))      IS NOT NULL
	DBCC CHECKIDENT ('dbo.Cennik',      RESEED, 0) WITH NO_INFOMSGS;
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.Wypozyczenie'))IS NOT NULL
	DBCC CHECKIDENT ('dbo.Wypozyczenie',RESEED, 0) WITH NO_INFOMSGS;
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.Doladowanie')) IS NOT NULL
	DBCC CHECKIDENT ('dbo.Doladowanie', RESEED, 0) WITH NO_INFOMSGS;
GO


--SEKCJA B - dane bazowe (uzytkownicy, stacje, pojazdy, cenniki)

--10 uzytkownikow (saldo wyzeruje sie z DEFAULT, doladowania w sekcji C)
INSERT INTO dbo.Uzytkownik (imie, nazwisko, email, telefon) VALUES
	(N'Jan',      N'Kowalski',  N'jan.kowalski@example.com',  N'600100001'),
	(N'Anna',     N'Nowak',     N'anna.nowak@example.com',    N'600100002'),
	(N'Piotr',    N'Wisniewski',N'piotr.w@example.com',       N'600100003'),
	(N'Maria',    N'Wojcik',    N'maria.wojcik@example.com',  N'600100004'),
	(N'Tomasz',   N'Kowalczyk', N'tomasz.k@example.com',      N'600100005'),
	(N'Katarzyna',N'Kaminska',  N'kasia.k@example.com',       N'600100006'),
	(N'Pawel',    N'Lewandowski',N'pawel.l@example.com',      N'600100007'),
	(N'Magdalena',N'Zielinska', N'magda.z@example.com',       N'600100008'),
	(N'Andrzej',  N'Szymanski', N'andrzej.s@example.com',     N'600100009'),
	(N'Joanna',   N'Wozniak',   N'joanna.w@example.com',      N'600100010');
GO

--6 stacji w roznych dzielnicach
INSERT INTO dbo.Stacja (nazwa, adres, pojemnosc) VALUES
	(N'Stacja Rynek',           N'ul. Rynek 1',          15),
	(N'Stacja Dworzec Glowny',  N'ul. Dworcowa 5',       20),
	(N'Stacja Politechnika',    N'ul. Akademicka 7',     12),
	(N'Stacja Centrum Handlowe',N'ul. Handlowa 12',      18),
	(N'Stacja Park',            N'ul. Parkowa 3',        10),
	(N'Stacja Stadion',         N'ul. Stadionowa 1',     15);
GO

--3 cenniki dla roweru (historia zmian stawki) + 2 dla hulajnogi
INSERT INTO dbo.Cennik (typ_pojazdu, stawka_za_minute, data_od, data_do) VALUES
	(N'rower',     0.40, '2024-01-01', '2024-12-31'),  -- id 1: stary
	(N'rower',     0.50, '2025-01-01', '2025-12-31'),  -- id 2: poprzedni
	(N'rower',     0.60, '2026-01-01', NULL),          -- id 3: aktualny
	(N'hulajnoga', 0.70, '2024-01-01', '2025-12-31'),  -- id 4: poprzedni
	(N'hulajnoga', 0.80, '2026-01-01', NULL);          -- id 5: aktualny
GO

--30 pojazdow (20 rowerow + 10 hulajnog) rozlozonych na stacjach 1-6
INSERT INTO dbo.Pojazd (typ, numer_seryjny, status, stan_techniczny, id_stacji) VALUES
	-- Stacja 1 (Rynek): 4 rowery + 2 hulajnogi
	(N'rower',     N'R-001', N'dostepny',  N'sprawny',    1),
	(N'rower',     N'R-002', N'dostepny',  N'sprawny',    1),
	(N'rower',     N'R-003', N'dostepny',  N'sprawny',    1),
	(N'rower',     N'R-004', N'dostepny',  N'sprawny',    1),
	(N'hulajnoga', N'H-001', N'dostepny',  N'sprawny',    1),
	(N'hulajnoga', N'H-002', N'dostepny',  N'sprawny',    1),
	-- Stacja 2 (Dworzec): 5 rowerow + 3 hulajnogi
	(N'rower',     N'R-005', N'dostepny',  N'sprawny',    2),
	(N'rower',     N'R-006', N'dostepny',  N'sprawny',    2),
	(N'rower',     N'R-007', N'dostepny',  N'sprawny',    2),
	(N'rower',     N'R-008', N'dostepny',  N'sprawny',    2),
	(N'rower',     N'R-009', N'dostepny',  N'uszkodzony', 2),  -- uszkodzony
	(N'hulajnoga', N'H-003', N'dostepny',  N'sprawny',    2),
	(N'hulajnoga', N'H-004', N'dostepny',  N'sprawny',    2),
	(N'hulajnoga', N'H-005', N'dostepny',  N'sprawny',    2),
	-- Stacja 3 (Politechnika): 4 rowery + 1 hulajnoga
	(N'rower',     N'R-010', N'dostepny',  N'sprawny',    3),
	(N'rower',     N'R-011', N'dostepny',  N'sprawny',    3),
	(N'rower',     N'R-012', N'dostepny',  N'sprawny',    3),
	(N'rower',     N'R-013', N'w serwisie',N'uszkodzony', 3),  -- w serwisie
	(N'hulajnoga', N'H-006', N'dostepny',  N'sprawny',    3),
	-- Stacja 4 (Centrum): 3 rowery + 2 hulajnogi
	(N'rower',     N'R-014', N'dostepny',  N'sprawny',    4),
	(N'rower',     N'R-015', N'dostepny',  N'sprawny',    4),
	(N'rower',     N'R-016', N'dostepny',  N'sprawny',    4),
	(N'hulajnoga', N'H-007', N'dostepny',  N'sprawny',    4),
	(N'hulajnoga', N'H-008', N'dostepny',  N'sprawny',    4),
	-- Stacja 5 (Park): 2 rowery + 1 hulajnoga
	(N'rower',     N'R-017', N'dostepny',  N'sprawny',    5),
	(N'rower',     N'R-018', N'dostepny',  N'sprawny',    5),
	(N'hulajnoga', N'H-009', N'dostepny',  N'sprawny',    5),
	-- Stacja 6 (Stadion): 2 rowery + 1 hulajnoga
	(N'rower',     N'R-019', N'dostepny',  N'sprawny',    6),
	(N'rower',     N'R-020', N'dostepny',  N'sprawny',    6),
	(N'hulajnoga', N'H-010', N'dostepny',  N'sprawny',    6);
GO

--SEKCJA C - doladowania (przez usp_Doladuj z e08)

--Trigger TR_Doladowanie_AI_Saldo zwiekszy saldo uzytkownikow.

DECLARE @nowe DECIMAL(10,2);
DECLARE @i INT = 1;

WHILE @i <= 10
BEGIN
	-- kazdy uzytkownik dostaje 100zl startowo
	EXEC dbo.usp_Doladuj @id_uzytkownika = @i, @kwota = 100.00, @nowe_saldo = @nowe OUTPUT;
	SET @i = @i + 1;
END

--Dodatkowe doladowania dla najbardziej aktywnych
EXEC dbo.usp_Doladuj @id_uzytkownika = 1, @kwota =  50.00, @nowe_saldo = @nowe OUTPUT;
EXEC dbo.usp_Doladuj @id_uzytkownika = 1, @kwota = 200.00, @nowe_saldo = @nowe OUTPUT;
EXEC dbo.usp_Doladuj @id_uzytkownika = 2, @kwota = 150.00, @nowe_saldo = @nowe OUTPUT;
EXEC dbo.usp_Doladuj @id_uzytkownika = 3, @kwota = 100.00, @nowe_saldo = @nowe OUTPUT;
EXEC dbo.usp_Doladuj @id_uzytkownika = 5, @kwota =  50.00, @nowe_saldo = @nowe OUTPUT;
GO

-- SEKCJA D - wypozyczenia (historyczne + biezace + aktywne)

--D.1: 5 historycznych wypozyczen z 2025 (cennik rower id=2: 0.50/min)
DECLARE @id INT, @oplata DECIMAL(10,2);
DECLARE @start DATETIME2(0), @koniec DATETIME2(0);
DECLARE @nowe DECIMAL(10,2);  --uzywane w CATCH w petli D.2 (auto-doladowanie)

--Jan, rower R-001, 20 min w czerwcu 2025, zwrot na Dworzec
SET @start  = '2025-06-15 10:00:00';
SET @koniec = '2025-06-15 10:20:00';
EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=1, @id_pojazdu=1, @id_cennika=2,
	@id_stacji_startowej=1, @data_rozpoczecia=@start, @id_wypozyczenia=@id OUTPUT;
EXEC dbo.usp_ZakonczWypozyczenie    @id_wypozyczenia=@id, @id_stacji_koncowej=2,
	@data_zakonczenia=@koniec, @oplata=@oplata OUTPUT;

--Anna, hulajnoga H-001, 8 min lipiec 2025 (cennik hulajnoga id=4: 0.70/min)
SET @start  = '2025-07-04 14:30:00';
SET @koniec = '2025-07-04 14:38:00';
EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=2, @id_pojazdu=5, @id_cennika=4,
	@id_stacji_startowej=1, @data_rozpoczecia=@start, @id_wypozyczenia=@id OUTPUT;
EXEC dbo.usp_ZakonczWypozyczenie    @id_wypozyczenia=@id, @id_stacji_koncowej=3,
	@data_zakonczenia=@koniec, @oplata=@oplata OUTPUT;

--Piotr, rower R-007, 45 min wrzesien 2025
SET @start  = '2025-09-10 08:15:00';
SET @koniec = '2025-09-10 09:00:00';
EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=3, @id_pojazdu=9, @id_cennika=2,
	@id_stacji_startowej=2, @data_rozpoczecia=@start, @id_wypozyczenia=@id OUTPUT;
EXEC dbo.usp_ZakonczWypozyczenie    @id_wypozyczenia=@id, @id_stacji_koncowej=3,
	@data_zakonczenia=@koniec, @oplata=@oplata OUTPUT;

--Maria, rower R-010, 12 min listopad 2025, zwrot poza stacja (wspolrzedne)
SET @start  = '2025-11-20 18:00:00';
SET @koniec = '2025-11-20 18:12:00';
EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=4, @id_pojazdu=15, @id_cennika=2,
	@id_stacji_startowej=3, @data_rozpoczecia=@start, @id_wypozyczenia=@id OUTPUT;
EXEC dbo.usp_ZakonczWypozyczenie    @id_wypozyczenia=@id,
	@koncowa_szerokosc=46.770439, @koncowa_dlugosc=23.591423,
	@data_zakonczenia=@koniec, @oplata=@oplata OUTPUT;

--Tomasz, rower R-014, 25 min grudzien 2025
SET @start  = '2025-12-05 12:00:00';
SET @koniec = '2025-12-05 12:25:00';
EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=5, @id_pojazdu=20, @id_cennika=2,
	@id_stacji_startowej=4, @data_rozpoczecia=@start, @id_wypozyczenia=@id OUTPUT;
EXEC dbo.usp_ZakonczWypozyczenie    @id_wypozyczenia=@id, @id_stacji_koncowej=1,
	@data_zakonczenia=@koniec, @oplata=@oplata OUTPUT;

--D.2: 20 wypozyczen z ostatnich 30 dni (aktualny cennik: rower id=3, hulajnoga id=5)
--Pomocnicze tabele z faktycznymi id pojazdow rozbitych na typ (id w bazie
--nie laduja zwartym blokiem - rowery i hulajnogi sa przeplatane po stacjach,
--a R-009 id=11 jest 'uszkodzony' i R-013 id=18 'w serwisie' wiec sa wykluczone).

DECLARE @rowery_dost TABLE (rn INT IDENTITY(1,1) PRIMARY KEY, id INT);
INSERT INTO @rowery_dost (id) VALUES
	(1),(2),(3),(4),(7),(8),(9),(10),(15),(16),(17),(20),(21),(22),(25),(26),(28),(29);
DECLARE @hulajnogi TABLE (rn INT IDENTITY(1,1) PRIMARY KEY, id INT);
INSERT INTO @hulajnogi (id) VALUES
	(5),(6),(12),(13),(14),(19),(23),(24),(27),(30);

DECLARE @loop INT = 1;
DECLARE @uz INT, @poj INT, @cen INT, @st_a INT, @st_b INT, @dlug INT;
DECLARE @typ_rower BIT;

WHILE @loop <= 20
BEGIN
	--losowy uzytkownik 1-10
	SET @uz = ((@loop * 7) % 10) + 1;

	--co druga iteracja rower, co druga hulajnoga
	SET @typ_rower = @loop % 2;

	--wybor pojazdu i cennika wg typu (z tablic odpowiedniego typu)
	IF @typ_rower = 1
	BEGIN
		SELECT @poj = id FROM @rowery_dost WHERE rn = ((@loop * 3) % 18) + 1;
		SET @cen = 3;                          -- cennik rower 0.60/min
	END
	ELSE
	BEGIN
		SELECT @poj = id FROM @hulajnogi   WHERE rn = ((@loop * 3) % 10) + 1;
		SET @cen = 5;                          -- cennik hulajnoga 0.80/min
	END

	--losowe stacje 1-6
	SET @st_a = ((@loop * 11) % 6) + 1;
	SET @st_b = ((@loop * 13) % 6) + 1;

	--dlugosc 5-40 minut
	SET @dlug = 5 + ((@loop * 17) % 36);

	--data: rozlozona w ostatnich 30 dniach
	SET @koniec = DATEADD(MINUTE, -((@loop * 47) % (30 * 24 * 60)), SYSDATETIME());
	SET @start  = DATEADD(MINUTE, -@dlug, @koniec);

	BEGIN TRY
		EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=@uz, @id_pojazdu=@poj,
			@id_cennika=@cen, @id_stacji_startowej=@st_a,
			@data_rozpoczecia=@start, @id_wypozyczenia=@id OUTPUT;
		EXEC dbo.usp_ZakonczWypozyczenie @id_wypozyczenia=@id, @id_stacji_koncowej=@st_b,
			@data_zakonczenia=@koniec, @oplata=@oplata OUTPUT;
	END TRY
	BEGIN CATCH
		--rzadki przypadek: za male saldo. Doladowujemy i powtarzamy.
		EXEC dbo.usp_Doladuj @id_uzytkownika=@uz, @kwota=50.00, @nowe_saldo=@nowe OUTPUT;
		EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=@uz, @id_pojazdu=@poj,
			@id_cennika=@cen, @id_stacji_startowej=@st_a,
			@data_rozpoczecia=@start, @id_wypozyczenia=@id OUTPUT;
		EXEC dbo.usp_ZakonczWypozyczenie @id_wypozyczenia=@id, @id_stacji_koncowej=@st_b,
			@data_zakonczenia=@koniec, @oplata=@oplata OUTPUT;
	END CATCH

	SET @loop = @loop + 1;
END
GO

--D.3: 3 aktywne (nie zakonczone) wypozyczenia

DECLARE @id INT;
DECLARE @start DATETIME2(0);

SET @start = DATEADD(MINUTE, -15, SYSDATETIME());
EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=1, @id_pojazdu=2, @id_cennika=3,
	@id_stacji_startowej=1, @data_rozpoczecia=@start, @id_wypozyczenia=@id OUTPUT;

SET @start = DATEADD(MINUTE, -8, SYSDATETIME());
EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=2, @id_pojazdu=6, @id_cennika=5,
	@id_stacji_startowej=1, @data_rozpoczecia=@start, @id_wypozyczenia=@id OUTPUT;

SET @start = DATEADD(MINUTE, -3, SYSDATETIME());
EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=3, @id_pojazdu=16, @id_cennika=3,
	@id_stacji_startowej=4, @data_rozpoczecia=@start, @id_wypozyczenia=@id OUTPUT;
GO

-- SEKCJA E - procedury testujace (usp_Test*)

--Wzorzec: kazda procedura zwraca jeden wiersz (test, oczekiwane,
--faktyczne, status) i jednoczesnie wpisuje ten sam wiersz do tabeli
--dbo.WynikiTestow. Procedura nadrzedna usp_TestyWszystkie czyta wyniki
--z tej tabeli (nie da sie uzyc INSERT INTO @tabela EXEC, bo testy
--wywoluja procedury z e08 ktore robia ROLLBACK w triggerach, a ROLLBACK
--w INSERT-EXEC jest zabroniony - Msg 3915).
--Wszystkie zmiany w danych dzieja sie w BEGIN TRAN i sa cofane przez
--ROLLBACK, zeby testy nie zasmiecaly bazy.

--Tabela na wyniki testow (idempotentnie - tworzymy raz, pozniej tylko TRUNCATE)
IF OBJECT_ID('dbo.WynikiTestow', 'U') IS NULL
BEGIN
	CREATE TABLE dbo.WynikiTestow (
		nr         INT IDENTITY(1,1) PRIMARY KEY,
		test       NVARCHAR(100),
		oczekiwane NVARCHAR(50),
		faktyczne  NVARCHAR(50),
		status     NVARCHAR(10)
	);
END
GO

--Test 1: ZPB4 - przekroczenie pojemnosci stacji (blad 50001)
IF OBJECT_ID('dbo.usp_TestZPB4_Pojemnosc', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestZPB4_Pojemnosc;
GO
CREATE PROCEDURE usp_TestZPB4_Pojemnosc
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @err INT = 0, @status NVARCHAR(10);

	BEGIN TRY
		BEGIN TRAN;
		--Stacja 5 ma pojemnosc 10. Po sekcji D.2 liczba pojazdow tam jest
		--niedeterministyczna (od 0 do ok. 6), wiec wstawiamy 11 nowych
		--pojazdow - to gwarantuje przekroczenie pojemnosci niezaleznie od
		--aktualnego stanu (najgorszy przypadek: 0 + 11 = 11 > 10 -> trigger).
		DECLARE @i INT = 0;
		WHILE @i < 11
		BEGIN
			INSERT INTO dbo.Pojazd (typ, numer_seryjny, status, stan_techniczny, id_stacji)
			VALUES (N'rower', N'TEST-P-' + CAST(@i AS NVARCHAR(5)),
			        N'dostepny', N'sprawny', 5);
			SET @i = @i + 1;
		END
		ROLLBACK TRAN;  --nieoczekiwane: nie wywalilo bledu
	END TRY
	BEGIN CATCH
		SET @err = ERROR_NUMBER();
		IF XACT_STATE() <> 0 ROLLBACK TRAN;
	END CATCH

	SET @status = CASE WHEN @err = 50001 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('ZPB4 (pojemnosc stacji)', '50001', CAST(@err AS VARCHAR(10)), @status);
	SELECT 'ZPB4 (pojemnosc stacji)' AS [Test 1], '50001' AS oczekiwane,
	       CAST(@err AS VARCHAR(10)) AS faktyczne, @status AS status;
END
GO

--Test 2: ZPB1 - wypozyczenie niedostepnego pojazdu (blad 50002)
IF OBJECT_ID('dbo.usp_TestZPB1_Niedostepny', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestZPB1_Niedostepny;
GO
CREATE PROCEDURE usp_TestZPB1_Niedostepny
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @err INT = 0, @status NVARCHAR(10), @id INT;

	BEGIN TRY
		BEGIN TRAN;
		--Pojazd id=18 (R-013) jest 'w serwisie' - usp_RozpocznijWypozyczenie
		--powinno rzucic 50002.
		EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=1, @id_pojazdu=18,
			@id_cennika=3, @id_stacji_startowej=3, @id_wypozyczenia=@id OUTPUT;
		ROLLBACK TRAN;
	END TRY
	BEGIN CATCH
		SET @err = ERROR_NUMBER();
		IF XACT_STATE() <> 0 ROLLBACK TRAN;
	END CATCH

	SET @status = CASE WHEN @err = 50002 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('ZPB1 (pojazd niedostepny)', '50002', CAST(@err AS VARCHAR(10)), @status);
	SELECT 'ZPB1 (pojazd niedostepny)' AS [Test 2], '50002' AS oczekiwane,
	       CAST(@err AS VARCHAR(10)) AS faktyczne, @status AS status;
END
GO

--Test 3: ZPB5 - zerowe saldo przy starcie wypozyczenia (blad 50003)
IF OBJECT_ID('dbo.usp_TestZPB5_SaldoStart', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestZPB5_SaldoStart;
GO
CREATE PROCEDURE usp_TestZPB5_SaldoStart
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @err INT = 0, @status NVARCHAR(10), @id INT, @uz INT;

	BEGIN TRY
		BEGIN TRAN;
		-- Dodajemy nowego uzytkownika z saldem 0 (DEFAULT)
		INSERT INTO dbo.Uzytkownik (imie, nazwisko, email, telefon)
		VALUES (N'Test', N'BezSalda', N'bezsalda@test.com', N'600999000');
		SET @uz = SCOPE_IDENTITY();

		EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=@uz, @id_pojazdu=4,
			@id_cennika=3, @id_stacji_startowej=1, @id_wypozyczenia=@id OUTPUT;
		ROLLBACK TRAN;
	END TRY
	BEGIN CATCH
		SET @err = ERROR_NUMBER();
		IF XACT_STATE() <> 0 ROLLBACK TRAN;
	END CATCH

	SET @status = CASE WHEN @err = 50003 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('ZPB5 (saldo<=0 przy starcie)', '50003', CAST(@err AS VARCHAR(10)), @status);
	SELECT 'ZPB5 (saldo<=0 przy starcie)' AS [Test 3], '50003' AS oczekiwane,
	       CAST(@err AS VARCHAR(10)) AS faktyczne, @status AS status;
END
GO

--Test 4: ZPB7 - cennik nie pasuje do pojazdu (blad 50004)
IF OBJECT_ID('dbo.usp_TestZPB7_CennikMismatch', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestZPB7_CennikMismatch;
GO
CREATE PROCEDURE usp_TestZPB7_CennikMismatch
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @err INT = 0, @status NVARCHAR(10), @id INT;

	BEGIN TRY
		BEGIN TRAN;
		-- Probujemy wypozyczyc rower (id=4) na cenniku hulajnogi (id=5).
		EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=1, @id_pojazdu=4,
			@id_cennika=5, @id_stacji_startowej=1, @id_wypozyczenia=@id OUTPUT;
		ROLLBACK TRAN;
	END TRY
	BEGIN CATCH
		SET @err = ERROR_NUMBER();
		IF XACT_STATE() <> 0 ROLLBACK TRAN;
	END CATCH

	SET @status = CASE WHEN @err = 50004 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('ZPB7 (cennik nie pasuje)', '50004', CAST(@err AS VARCHAR(10)), @status);
	SELECT 'ZPB7 (cennik nie pasuje)' AS [Test 4], '50004' AS oczekiwane,
	       CAST(@err AS VARCHAR(10)) AS faktyczne, @status AS status;
END
GO

--Test 5: ZPB5 - niewystarczajace saldo przy zakonczeniu (blad 50005)
IF OBJECT_ID('dbo.usp_TestZPB5_SaldoKoniec', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestZPB5_SaldoKoniec;
GO
CREATE PROCEDURE usp_TestZPB5_SaldoKoniec
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @err INT = 0, @status NVARCHAR(10);
	DECLARE @id INT, @uz INT, @oplata DECIMAL(10,2), @nowe DECIMAL(10,2);
	DECLARE @start DATETIME2(0), @koniec DATETIME2(0);

	BEGIN TRY
		BEGIN TRAN;
		-- Uzytkownik z minimalnym saldem 1zl
		INSERT INTO dbo.Uzytkownik (imie, nazwisko, email, telefon)
		VALUES (N'Test', N'MaleSaldo', N'malesaldo@test.com', N'600999001');
		SET @uz = SCOPE_IDENTITY();
		EXEC dbo.usp_Doladuj @id_uzytkownika=@uz, @kwota=1.00, @nowe_saldo=@nowe OUTPUT;

		-- 60 min na rowerze (0.60/min) = 36zl >> 1zl => oplata > saldo
		SET @start  = DATEADD(MINUTE, -60, SYSDATETIME());
		SET @koniec = SYSDATETIME();
		EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=@uz, @id_pojazdu=4,
			@id_cennika=3, @id_stacji_startowej=1, @data_rozpoczecia=@start,
			@id_wypozyczenia=@id OUTPUT;
		EXEC dbo.usp_ZakonczWypozyczenie @id_wypozyczenia=@id, @id_stacji_koncowej=2,
			@data_zakonczenia=@koniec, @oplata=@oplata OUTPUT;
		ROLLBACK TRAN;
	END TRY
	BEGIN CATCH
		SET @err = ERROR_NUMBER();
		IF XACT_STATE() <> 0 ROLLBACK TRAN;
	END CATCH

	SET @status = CASE WHEN @err = 50005 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('ZPB5 (saldo<oplata przy koncu)', '50005', CAST(@err AS VARCHAR(10)), @status);
	SELECT 'ZPB5 (saldo<oplata przy koncu)' AS [Test 5], '50005' AS oczekiwane,
	       CAST(@err AS VARCHAR(10)) AS faktyczne, @status AS status;
END
GO

--Test 6: ZPB6 - nakladanie zakresow cennika (blad 50006)
IF OBJECT_ID('dbo.usp_TestZPB6_NakladanieCennika', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestZPB6_NakladanieCennika;
GO
CREATE PROCEDURE usp_TestZPB6_NakladanieCennika
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @err INT = 0, @status NVARCHAR(10);

	BEGIN TRY
		BEGIN TRAN;
		-- Aktualny cennik rower (id=3) obowiazuje od 2026-01-01. Probujemy
		-- dodac drugi cennik rower zachodzacy na ten okres.
		INSERT INTO dbo.Cennik (typ_pojazdu, stawka_za_minute, data_od, data_do)
		VALUES (N'rower', 0.65, '2026-03-01', '2026-09-30');
		ROLLBACK TRAN;
	END TRY
	BEGIN CATCH
		SET @err = ERROR_NUMBER();
		IF XACT_STATE() <> 0 ROLLBACK TRAN;
	END CATCH

	SET @status = CASE WHEN @err = 50006 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('ZPB6 (nakladanie cennika)', '50006', CAST(@err AS VARCHAR(10)), @status);
	SELECT 'ZPB6 (nakladanie cennika)' AS [Test 6], '50006' AS oczekiwane,
	       CAST(@err AS VARCHAR(10)) AS faktyczne, @status AS status;
END
GO

--Test 7: usp_ZakonczWypozyczenie dla nieistniejacego id (blad 50007)
IF OBJECT_ID('dbo.usp_TestProc50007', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestProc50007;
GO
CREATE PROCEDURE usp_TestProc50007
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @err INT = 0, @status NVARCHAR(10), @oplata DECIMAL(10,2);

	BEGIN TRY
		BEGIN TRAN;
		EXEC dbo.usp_ZakonczWypozyczenie @id_wypozyczenia = 999999,
			@id_stacji_koncowej = 1, @oplata = @oplata OUTPUT;
		ROLLBACK TRAN;
	END TRY
	BEGIN CATCH
		SET @err = ERROR_NUMBER();
		IF XACT_STATE() <> 0 ROLLBACK TRAN;
	END CATCH

	SET @status = CASE WHEN @err = 50007 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('usp_Zakoncz (rental nie istnieje)', '50007', CAST(@err AS VARCHAR(10)), @status);
	SELECT 'usp_Zakoncz (rental nie istnieje)' AS [Test 7], '50007' AS oczekiwane,
	       CAST(@err AS VARCHAR(10)) AS faktyczne, @status AS status;
END
GO

--Test 8: ZPB9 - doladowanie zwieksza saldo (test pozytywny)
IF OBJECT_ID('dbo.usp_TestZPB9_Doladowanie', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestZPB9_Doladowanie;
GO
CREATE PROCEDURE usp_TestZPB9_Doladowanie
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @status NVARCHAR(10);
	DECLARE @uz INT, @saldo_przed DECIMAL(10,2), @saldo_po DECIMAL(10,2);
	DECLARE @nowe DECIMAL(10,2);

	BEGIN TRAN;
		SELECT @uz = 1;
		SELECT @saldo_przed = saldo FROM dbo.Uzytkownik WHERE id_uzytkownika = @uz;
		EXEC dbo.usp_Doladuj @id_uzytkownika=@uz, @kwota=25.50, @nowe_saldo=@nowe OUTPUT;
		SELECT @saldo_po = saldo FROM dbo.Uzytkownik WHERE id_uzytkownika = @uz;
	ROLLBACK TRAN;

	SET @status = CASE WHEN @saldo_po = @saldo_przed + 25.50 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('ZPB9 (doladowanie zwieksza saldo)',
	        CAST(@saldo_przed + 25.50 AS VARCHAR(20)),
	        CAST(@saldo_po AS VARCHAR(20)),
	        @status);
	SELECT 'ZPB9 (doladowanie zwieksza saldo)' AS [Test 8],
	       CAST(@saldo_przed + 25.50 AS VARCHAR(20)) AS oczekiwane,
	       CAST(@saldo_po AS VARCHAR(20))            AS faktyczne,
	       @status AS status;
END
GO

--Test 9: ZPB1 + ZPB8 - po zwrocie status pojazdu wraca na 'dostepny' (na stacje)
--lub 'do zadokowania' (poza stacja). Test pozytywny.
IF OBJECT_ID('dbo.usp_TestZPB1_StatusPoZwrocie', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestZPB1_StatusPoZwrocie;
GO
CREATE PROCEDURE usp_TestZPB1_StatusPoZwrocie
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @status NVARCHAR(10);
	DECLARE @id INT, @oplata DECIMAL(10,2);
	DECLARE @start DATETIME2(0), @koniec DATETIME2(0);
	DECLARE @status_pojazdu NVARCHAR(20), @id_stacji INT;

	BEGIN TRAN;
		SET @start  = DATEADD(MINUTE, -5, SYSDATETIME());
		SET @koniec = SYSDATETIME();

		-- start
		EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=1, @id_pojazdu=3,
			@id_cennika=3, @id_stacji_startowej=1, @data_rozpoczecia=@start,
			@id_wypozyczenia=@id OUTPUT;

		-- zwrot na stacje 2
		EXEC dbo.usp_ZakonczWypozyczenie @id_wypozyczenia=@id, @id_stacji_koncowej=2,
			@data_zakonczenia=@koniec, @oplata=@oplata OUTPUT;

		SELECT @status_pojazdu = status, @id_stacji = id_stacji
		FROM dbo.Pojazd WHERE id_pojazdu = 3;
	ROLLBACK TRAN;

	SET @status = CASE
		WHEN @status_pojazdu = N'dostepny' AND @id_stacji = 2 THEN 'PASS'
		ELSE 'FAIL'
	END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('ZPB1/8 (status po zwrocie na stacje)',
	        'dostepny@stacja2',
	        ISNULL(@status_pojazdu, '<null>') + '@stacja' + ISNULL(CAST(@id_stacji AS VARCHAR(5)), '<null>'),
	        @status);
	SELECT 'ZPB1/8 (status po zwrocie na stacje)' AS [Test 9],
	       'dostepny@stacja2'                                                AS oczekiwane,
	       ISNULL(@status_pojazdu, '<null>') + '@stacja' + ISNULL(CAST(@id_stacji AS VARCHAR(5)), '<null>') AS faktyczne,
	       @status AS status;

	--Dodatkowy wynik: stan pojazdu nr 3 zlapany wewnatrz transakcji
	--(dowod ze logika faktycznie zmienila wiersz przed ROLLBACK-iem)
	SELECT 3 AS id_pojazdu, @status_pojazdu AS status_pojazdu, @id_stacji AS id_stacji;
END
GO


--Test 10: naliczanie oplaty (Z3 z e07: minuta rozpoczeta = pelna minuta).
--3 minuty i 30 sekund = 4 minuty platne.
IF OBJECT_ID('dbo.usp_TestNaliczanie', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestNaliczanie;
GO
CREATE PROCEDURE usp_TestNaliczanie
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @status NVARCHAR(10);
	DECLARE @id INT, @oplata DECIMAL(10,2);
	DECLARE @start DATETIME2(0), @koniec DATETIME2(0);

	BEGIN TRAN;
		SET @start  = '2026-06-01 10:00:00';
		SET @koniec = '2026-06-01 10:03:30';   --3 min 30 s -> 4 min platne
		EXEC dbo.usp_RozpocznijWypozyczenie @id_uzytkownika=1, @id_pojazdu=4,
			@id_cennika=3, @id_stacji_startowej=1, @data_rozpoczecia=@start,
			@id_wypozyczenia=@id OUTPUT;
		EXEC dbo.usp_ZakonczWypozyczenie @id_wypozyczenia=@id, @id_stacji_koncowej=2,
			@data_zakonczenia=@koniec, @oplata=@oplata OUTPUT;
	ROLLBACK TRAN;

	--4 min * 0.60/min = 2.40
	SET @status = CASE WHEN @oplata = 2.40 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('Naliczanie (3min30s -> 4 min)', '2.40', CAST(@oplata AS VARCHAR(20)), @status);
	SELECT 'Naliczanie (3min30s -> 4 min)' AS [Test 10], '2.40' AS oczekiwane,
	       CAST(@oplata AS VARCHAR(20)) AS faktyczne, @status AS status;
END
GO

--Test 11: W1 - walidacja unikalnosci email (deklaratywna integralnosc z e06).
--UQ_Uzytkownik_email pilnuje, ze jeden adres email = jeden uzytkownik.
--Probujemy zarejestrowac drugiego uzytkownika z mailem juz uzytym przez Jana
--Kowalskiego -> oczekiwany Msg 2627 (naruszenie UNIQUE/PRIMARY KEY).
IF OBJECT_ID('dbo.usp_TestW1_DuplikatEmail', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestW1_DuplikatEmail;
GO
CREATE PROCEDURE usp_TestW1_DuplikatEmail
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @err INT = 0, @status NVARCHAR(10);

	BEGIN TRY
		BEGIN TRAN;
		INSERT INTO dbo.Uzytkownik (imie, nazwisko, email, telefon)
		VALUES (N'Test', N'Duplikat', N'jan.kowalski@example.com', N'600999100');
		ROLLBACK TRAN;
	END TRY
	BEGIN CATCH
		SET @err = ERROR_NUMBER();
		IF XACT_STATE() <> 0 ROLLBACK TRAN;
	END CATCH

	SET @status = CASE WHEN @err = 2627 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('W1 (duplikat email - UNIQUE)', '2627', CAST(@err AS VARCHAR(10)), @status);
	SELECT 'W1 (duplikat email - UNIQUE)' AS [Test 11], '2627' AS oczekiwane,
	       CAST(@err AS VARCHAR(10)) AS faktyczne, @status AS status;
END
GO

--Test 12: vw_AktywneWypozyczenia (e09) - liczba wierszy.
--Sekcja D.3 wstawia dokladnie 3 aktywne wypozyczenia (deterministyczne).
IF OBJECT_ID('dbo.usp_TestE09_AktywneWypozyczenia', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestE09_AktywneWypozyczenia;
GO
CREATE PROCEDURE usp_TestE09_AktywneWypozyczenia
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @cnt INT, @status NVARCHAR(10);
	SELECT @cnt = COUNT(*) FROM dbo.vw_AktywneWypozyczenia;
	SET @status = CASE WHEN @cnt = 3 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('E09 vw_AktywneWypozyczenia (count)', '3', CAST(@cnt AS VARCHAR(10)), @status);
	SELECT 'E09 vw_AktywneWypozyczenia (count)' AS [Test 12], '3' AS oczekiwane,
	       CAST(@cnt AS VARCHAR(10)) AS faktyczne, @status AS status;

	--Diagnostyka: gdy FAIL pokazujemy aktualna zawartosc widoku
	--(pomaga szybko zobaczyc co poszlo nie tak z danymi z sekcji D.3)
	IF @status = 'FAIL'
		SELECT * FROM dbo.vw_AktywneWypozyczenia;
END
GO

--Test 13: vw_HistoriaWypozyczen (e09) - liczba wierszy.
--Sekcje D.1 (5) + D.2 (20) = 25 zakonczonych wypozyczen + ewentualne retry
--z bloku CATCH w D.2 (dolicza sie do calej historii).
IF OBJECT_ID('dbo.usp_TestE09_HistoriaWypozyczen', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestE09_HistoriaWypozyczen;
GO
CREATE PROCEDURE usp_TestE09_HistoriaWypozyczen
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @cnt INT, @status NVARCHAR(10);
	SELECT @cnt = COUNT(*) FROM dbo.vw_HistoriaWypozyczen;
	SET @status = CASE WHEN @cnt >= 25 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('E09 vw_HistoriaWypozyczen (count)', '>=25', CAST(@cnt AS VARCHAR(10)), @status);
	SELECT 'E09 vw_HistoriaWypozyczen (count)' AS [Test 13], '>=25' AS oczekiwane,
	       CAST(@cnt AS VARCHAR(10)) AS faktyczne, @status AS status;
END
GO

--Test 14: vw_AktualnyCennik (e09) - liczba wierszy.
--Z 5 cennikow w sekcji B tylko 2 sa otwarte na 2026 (id 3 rower + id 5 hulajnoga).
IF OBJECT_ID('dbo.usp_TestE09_AktualnyCennik', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestE09_AktualnyCennik;
GO
CREATE PROCEDURE usp_TestE09_AktualnyCennik
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @cnt INT, @status NVARCHAR(10);
	SELECT @cnt = COUNT(*) FROM dbo.vw_AktualnyCennik;
	SET @status = CASE WHEN @cnt = 2 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('E09 vw_AktualnyCennik (count)', '2', CAST(@cnt AS VARCHAR(10)), @status);
	SELECT 'E09 vw_AktualnyCennik (count)' AS [Test 14], '2' AS oczekiwane,
	       CAST(@cnt AS VARCHAR(10)) AS faktyczne, @status AS status;
END
GO

--Test 15: fn_StawkaAktualna (e09) - wartosci dla 3 dat.
--rower w 2026 -> cennik id 3 (0.60); w 2025 -> id 2 (0.50); w 2020 -> brak -> NULL.
IF OBJECT_ID('dbo.usp_TestE09_FnStawkaAktualna', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestE09_FnStawkaAktualna;
GO
CREATE PROCEDURE usp_TestE09_FnStawkaAktualna
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @v1 DECIMAL(10,2), @v2 DECIMAL(10,2), @v3 DECIMAL(10,2);
	DECLARE @status NVARCHAR(10);

	SELECT @v1 = dbo.fn_StawkaAktualna(N'rower', '2026-06-17');
	SELECT @v2 = dbo.fn_StawkaAktualna(N'rower', '2025-06-01');
	SELECT @v3 = dbo.fn_StawkaAktualna(N'rower', '2020-01-01');

	SET @status = CASE
		WHEN @v1 = 0.60 AND @v2 = 0.50 AND @v3 IS NULL THEN 'PASS'
		ELSE 'FAIL'
	END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('E09 fn_StawkaAktualna (3 daty)',
	        '0.60/0.50/NULL',
	        CAST(@v1 AS VARCHAR(10)) + '/' + CAST(@v2 AS VARCHAR(10)) + '/'
	          + ISNULL(CAST(@v3 AS VARCHAR(10)), 'NULL'),
	        @status);
	SELECT 'E09 fn_StawkaAktualna (3 daty)' AS [Test 15],
	       '0.60/0.50/NULL' AS oczekiwane,
	       CAST(@v1 AS VARCHAR(10)) + '/' + CAST(@v2 AS VARCHAR(10)) + '/'
	         + ISNULL(CAST(@v3 AS VARCHAR(10)), 'NULL') AS faktyczne,
	       @status AS status;
END
GO

--Test 16: W6 - historia rozliczen uzytkownika.
--Sprawdzamy ze dla uzytkownika 1 (Jan) sa wpisy w obu tabelach historii
--(Wypozyczenie, Doladowanie) i saldo > 0 - czyli dane do usp_RaportUzytkownika
--z e09 sa realne. Wprost procedury nie wolamy (zwraca 3 result-sety, nie da
--sie INSERT EXEC do jednej tabeli) - sprawdzamy stan podstawowy.
IF OBJECT_ID('dbo.usp_TestW6_HistoriaUzytkownika', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestW6_HistoriaUzytkownika;
GO
CREATE PROCEDURE usp_TestW6_HistoriaUzytkownika
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @saldo DECIMAL(10,2), @cnt_w INT, @cnt_d INT;
	DECLARE @status NVARCHAR(10);

	SELECT @saldo = saldo FROM dbo.Uzytkownik WHERE id_uzytkownika = 1;
	SELECT @cnt_w = COUNT(*) FROM dbo.Wypozyczenie WHERE id_uzytkownika = 1;
	SELECT @cnt_d = COUNT(*) FROM dbo.Doladowanie  WHERE id_uzytkownika = 1;

	SET @status = CASE WHEN @saldo > 0 AND @cnt_w > 0 AND @cnt_d > 0 THEN 'PASS' ELSE 'FAIL' END;
	INSERT INTO dbo.WynikiTestow (test, oczekiwane, faktyczne, status)
	VALUES ('W6 (historia uzytkownika 1)',
	        'saldo>0, wyp>0, dol>0',
	        'saldo=' + CAST(@saldo AS VARCHAR(10))
	          + ', wyp=' + CAST(@cnt_w AS VARCHAR(10))
	          + ', dol=' + CAST(@cnt_d AS VARCHAR(10)),
	        @status);
	SELECT 'W6 (historia uzytkownika 1)' AS [Test 16],
	       'saldo>0, wyp>0, dol>0' AS oczekiwane,
	       'saldo=' + CAST(@saldo AS VARCHAR(10))
	         + ', wyp=' + CAST(@cnt_w AS VARCHAR(10))
	         + ', dol=' + CAST(@cnt_d AS VARCHAR(10)) AS faktyczne,
	       @status AS status;
END
GO

-- SEKCJA F - procedura nadrzedna usp_TestyWszystkie

--Czysci tabele wynikow, wola po kolei wszystkie usp_Test* (przez zwykly
--EXEC, NIE przez INSERT INTO @t EXEC - bo testy wywoluja procedury z e08,
--ktore robia ROLLBACK w triggerach, a ROLLBACK w INSERT-EXEC jest
--zabroniony przez SQL Server - Msg 3915), a na koniec wyswietla wyniki
--z dbo.WynikiTestow + podsumowanie (razem / pass / fail).

IF OBJECT_ID('dbo.usp_TestyWszystkie', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_TestyWszystkie;
GO

CREATE PROCEDURE usp_TestyWszystkie
AS
BEGIN
	SET NOCOUNT ON;

	TRUNCATE TABLE dbo.WynikiTestow;

	EXEC dbo.usp_TestZPB4_Pojemnosc;
	EXEC dbo.usp_TestZPB1_Niedostepny;
	EXEC dbo.usp_TestZPB5_SaldoStart;
	EXEC dbo.usp_TestZPB7_CennikMismatch;
	EXEC dbo.usp_TestZPB5_SaldoKoniec;
	EXEC dbo.usp_TestZPB6_NakladanieCennika;
	EXEC dbo.usp_TestProc50007;
	EXEC dbo.usp_TestZPB9_Doladowanie;
	EXEC dbo.usp_TestZPB1_StatusPoZwrocie;
	EXEC dbo.usp_TestNaliczanie;
	EXEC dbo.usp_TestW1_DuplikatEmail;
	EXEC dbo.usp_TestE09_AktywneWypozyczenia;
	EXEC dbo.usp_TestE09_HistoriaWypozyczen;
	EXEC dbo.usp_TestE09_AktualnyCennik;
	EXEC dbo.usp_TestE09_FnStawkaAktualna;
	EXEC dbo.usp_TestW6_HistoriaUzytkownika;

	SELECT nr, test, oczekiwane, faktyczne, status
	FROM dbo.WynikiTestow ORDER BY nr;

	SELECT
		COUNT(*)                                       AS razem,
		SUM(CASE WHEN status='PASS' THEN 1 ELSE 0 END) AS pass,
		SUM(CASE WHEN status='FAIL' THEN 1 ELSE 0 END) AS fail
	FROM dbo.WynikiTestow;
END
GO

-- SEKCJA G - uruchomienie testow + podsumowanie danych

PRINT '== Etap 10: dane zaladowane ==';
SELECT
	(SELECT COUNT(*) FROM dbo.Uzytkownik)  AS uzytkownicy,
	(SELECT COUNT(*) FROM dbo.Stacja)      AS stacje,
	(SELECT COUNT(*) FROM dbo.Pojazd)      AS pojazdy,
	(SELECT COUNT(*) FROM dbo.Cennik)      AS cenniki,
	(SELECT COUNT(*) FROM dbo.Doladowanie) AS doladowania,
	(SELECT COUNT(*) FROM dbo.Wypozyczenie WHERE data_zakonczenia IS NOT NULL) AS wypozyczenia_zakonczone,
	(SELECT COUNT(*) FROM dbo.Wypozyczenie WHERE data_zakonczenia IS NULL)     AS wypozyczenia_aktywne;
GO

PRINT 'Etap 10: wyniki testow w zakladce Results';
EXEC dbo.usp_TestyWszystkie;
GO

PRINT 'Etap 10: dane i testy zakonczone.';
GO
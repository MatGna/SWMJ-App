--Etap 9 - Implementacja kodu wspomagajacego aplikacje uzytkowa.
--System wynajmu miejskich jednosladow.
--
--Skrypt dokłada obiekty do czytania danych (to czego uzylaby aplikacja
--do pokazywania ekranow i raportow) oraz indeksy pod te zapytania:
--	* 3 indeksy niepogrupowane (w tym 1 filtrowany, 2 z INCLUDE)
--	* 4 widoki (vw_*)
--	* 2 funkcje skalarne (fn_*)
--	* 3 procedury raportowe (usp_Raport*)
--
--Skrypt idempotentny - przed utworzeniem kazdego obiektu DROP IF EXISTS.
--
--Wymaganie wstepne: baza WynajemJednosladow utworzona skryptem z etapu 6
--oraz wyzwalacze/procedury operacyjne z etapu 8.
--Sam etap 9 nie zaleznie funkcjonalnie od triggerow z e08 (odczyty nie
--odpalaja triggerow DML), ale w praktyce raporty maja sens po wczesniejszym
--zaladowaniu danych przez procedury z e08.

USE WynajemJednosladow;
GO

--INDEKSY WSPOMAGAJACE

--Uwaga: w etapie 6 zalozono juz indeksy na klucze obce (IX_Wypozyczenie_*,
--IX_Doladowanie_uzytkownik, IX_Pojazd_stacja). Tutaj dokladamy indeksy
--pod konkretne zapytania wprowadzone w etapie 9 (widoki/funkcje/raporty),
--ktorych klucze obce nie obsluguja:
--
--1) IX_Wypozyczenie_aktywne (filtrowany) - aktywne wypozyczenia
--		(vw_AktywneWypozyczenia, fn_PrognozowanaOplata).
--		Filtr WHERE data_zakonczenia IS NULL drastycznie zmniejsza
--		rozmiar indeksu (rosnie z czasem tylko o "biezace" wiersze).
--2) IX_Wypozyczenie_data_zakonczenia + INCLUDE(oplata,...) - raporty
--  	przychodow (usp_RaportPrzychodowOkres, vw_HistoriaWypozyczen).
--		INCLUDE umozliwia strategie "tylko indeks" - serwer nie musi
--		siegac do stron z danymi.
--3) IX_Doladowanie_data + INCLUDE(kwota,...) - analogicznie dla
--		raportu doladowan (usp_RaportUzytkownika).

--1) Indeks filtrowany na aktywne wypozyczenia
IF EXISTS (
	SELECT 1 FROM sys.indexes
	WHERE name = 'IX_Wypozyczenie_aktywne'
	  AND object_id = OBJECT_ID('dbo.Wypozyczenie')
)
	DROP INDEX IX_Wypozyczenie_aktywne ON dbo.Wypozyczenie;
GO

CREATE NONCLUSTERED INDEX IX_Wypozyczenie_aktywne
	ON dbo.Wypozyczenie (id_uzytkownika, id_pojazdu)
	INCLUDE (id_cennika, data_rozpoczecia, id_stacji_startowej)
	WHERE data_zakonczenia IS NULL;
GO

--2) Indeks na data_zakonczenia z INCLUDE pod raporty przychodow
IF EXISTS (
	SELECT 1 FROM sys.indexes
	WHERE name = 'IX_Wypozyczenie_data_zakonczenia'
	  AND object_id = OBJECT_ID('dbo.Wypozyczenie')
)
	DROP INDEX IX_Wypozyczenie_data_zakonczenia ON dbo.Wypozyczenie;
GO

CREATE NONCLUSTERED INDEX IX_Wypozyczenie_data_zakonczenia
	ON dbo.Wypozyczenie (data_zakonczenia)
	INCLUDE (oplata, data_rozpoczecia, id_uzytkownika, id_pojazdu);
GO

--3) Indeks na data doladowania z INCLUDE
IF EXISTS (
	SELECT 1 FROM sys.indexes
	WHERE name = 'IX_Doladowanie_data'
	  AND object_id = OBJECT_ID('dbo.Doladowanie')
)
	DROP INDEX IX_Doladowanie_data ON dbo.Doladowanie;
GO

CREATE NONCLUSTERED INDEX IX_Doladowanie_data
	ON dbo.Doladowanie (data)
	INCLUDE (kwota, id_uzytkownika);
GO

-- WIDOKI

--vw_AktywneWypozyczenia
--Lista trwajacych wypozyczen (data_zakonczenia IS NULL) z danymi
--uzytkownika, pojazdu, stacji startowej i biezacym czasem trwania.
--Glowny widok do panelu "co sie aktualnie dzieje" w aplikacji.

IF OBJECT_ID('dbo.vw_AktywneWypozyczenia', 'V') IS NOT NULL
	DROP VIEW dbo.vw_AktywneWypozyczenia;
GO

CREATE VIEW vw_AktywneWypozyczenia
AS
SELECT
	w.id_wypozyczenia,
	w.data_rozpoczecia,
	DATEDIFF(MINUTE, w.data_rozpoczecia, SYSDATETIME())		AS minuty_trwania,
	u.id_uzytkownika,
	u.imie,
	u.nazwisko,
	u.saldo,
	p.id_pojazdu,
	p.typ													AS typ_pojazdu,
	p.numer_seryjny,
	s.id_stacji												AS id_stacji_startowej,
	s.nazwa													AS nazwa_stacji_startowej,
	c.stawka_za_minute
FROM dbo.Wypozyczenie w
JOIN dbo.Uzytkownik   u ON u.id_uzytkownika = w.id_uzytkownika
JOIN dbo.Pojazd       p ON p.id_pojazdu     = w.id_pojazdu
JOIN dbo.Stacja       s ON s.id_stacji      = w.id_stacji_startowej
JOIN dbo.Cennik       c ON c.id_cennika     = w.id_cennika
WHERE w.data_zakonczenia IS NULL;
GO

--vw_PojazdyDostepneNaStacji
--Dla kazdej stacji i kazdego typu pojazdu - liczba sztuk gotowych
--do wynajecia (status = 'dostepny' AND stan_techniczny = 'sprawny').
--Wykorzystywane w widoku mapy stacji w aplikacji.

IF OBJECT_ID('dbo.vw_PojazdyDostepneNaStacji', 'V') IS NOT NULL
	DROP VIEW dbo.vw_PojazdyDostepneNaStacji;
GO

CREATE VIEW vw_PojazdyDostepneNaStacji
AS
SELECT
	s.id_stacji,
	s.nazwa					AS nazwa_stacji,
	s.adres,
	s.pojemnosc,
	p.typ					AS typ_pojazdu,
	COUNT(*)				AS liczba_dostepnych
FROM dbo.Stacja s
JOIN dbo.Pojazd p ON p.id_stacji = s.id_stacji
WHERE p.status = N'dostepny'
  AND p.stan_techniczny = N'sprawny'
GROUP BY s.id_stacji, s.nazwa, s.adres, s.pojemnosc, p.typ;
GO

--vw_HistoriaWypozyczen
--Zakonczone wypozyczenia z pelnym kontekstem (uzytkownik, pojazd,
--stacje, ewentualne wspolrzedne, czas trwania, oplata). Glowny widok
--dla raportow historycznych i ekranu "moje wypozyczenia".

IF OBJECT_ID('dbo.vw_HistoriaWypozyczen', 'V') IS NOT NULL
	DROP VIEW dbo.vw_HistoriaWypozyczen;
GO

CREATE VIEW vw_HistoriaWypozyczen
AS
SELECT
	w.id_wypozyczenia,
	w.data_rozpoczecia,
	w.data_zakonczenia,
	DATEDIFF(MINUTE, w.data_rozpoczecia, w.data_zakonczenia)	AS minuty,
	w.oplata,
	u.id_uzytkownika,
	u.imie,
	u.nazwisko,
	p.id_pojazdu,
	p.typ														AS typ_pojazdu,
	p.numer_seryjny,
	ss.id_stacji												AS id_stacji_startowej,
	ss.nazwa													AS nazwa_stacji_startowej,
	sk.id_stacji												AS id_stacji_koncowej,
	sk.nazwa													AS nazwa_stacji_koncowej,
	w.koncowa_szerokosc,
	w.koncowa_dlugosc
FROM dbo.Wypozyczenie w
JOIN dbo.Uzytkownik   u  ON u.id_uzytkownika = w.id_uzytkownika
JOIN dbo.Pojazd       p  ON p.id_pojazdu     = w.id_pojazdu
JOIN dbo.Stacja       ss ON ss.id_stacji     = w.id_stacji_startowej
LEFT JOIN dbo.Stacja  sk ON sk.id_stacji     = w.id_stacji_koncowej
WHERE w.data_zakonczenia IS NOT NULL;
GO

--vw_AktualnyCennik
--Cenniki obowiazujace w chwili odczytu widoku 
--(data_od <= teraz <= data_do; data_do = NULL oznacza otwarty zakres).

IF OBJECT_ID('dbo.vw_AktualnyCennik', 'V') IS NOT NULL
	DROP VIEW dbo.vw_AktualnyCennik;
GO

CREATE VIEW vw_AktualnyCennik
AS
SELECT
	id_cennika,
	typ_pojazdu,
	stawka_za_minute,
	data_od,
	data_do
FROM dbo.Cennik
WHERE data_od <= SYSDATETIME()
  AND (data_do IS NULL OR data_do >= SYSDATETIME());
GO

-- FUNKCJE

--fn_StawkaAktualna
--Zwraca stawke obowiazujaca dla danego typu pojazdu w zadanej chwili.
--NULL, jezeli w tej chwili nie ma cennika (mozliwe, jezeli zostala
--luka w datach - co zreszta blokuje TR_Cennik_AIU_Nakladanie tylko
--w przypadku nakladania, nie w przypadku luki).

IF OBJECT_ID('dbo.fn_StawkaAktualna', 'FN') IS NOT NULL
	DROP FUNCTION dbo.fn_StawkaAktualna;
GO

CREATE FUNCTION fn_StawkaAktualna (
	@typ_pojazdu	NVARCHAR(20),
	@data			DATETIME2(0)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
	DECLARE @stawka DECIMAL(10,2);

	SELECT @stawka = stawka_za_minute
	FROM dbo.Cennik
	WHERE typ_pojazdu = @typ_pojazdu
	  AND data_od <= @data
	  AND (data_do IS NULL OR data_do >= @data);

	RETURN @stawka;
END
GO

--fn_PrognozowanaOplata
--Dla trwajacego wypozyczenia liczy, ile wyniosla by oplata,
--gdyby zostalo zakonczone w chwili @na_chwile. Identyczna logika
--naliczania jak w usp_ZakonczWypozyczenie (etap 8): 
--minuta rozpoczeta = minuta oplacona, minimum 1 minuta.
--Zwraca NULL, jezeli wypozyczenie nie istnieje lub zostalo juz zakonczone.

IF OBJECT_ID('dbo.fn_PrognozowanaOplata', 'FN') IS NOT NULL
	DROP FUNCTION dbo.fn_PrognozowanaOplata;
GO

CREATE FUNCTION fn_PrognozowanaOplata (
	@id_wypozyczenia	INT,
	@na_chwile			DATETIME2(0)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
	DECLARE @data_rozpoczecia	DATETIME2(0);
	DECLARE @stawka				DECIMAL(10,2);
	DECLARE @minuty				INT;
	DECLARE @sekundy_reszta		INT;

	SELECT @data_rozpoczecia	= w.data_rozpoczecia,
	       @stawka				= c.stawka_za_minute
	FROM dbo.Wypozyczenie w
	JOIN dbo.Cennik       c ON c.id_cennika = w.id_cennika
	WHERE w.id_wypozyczenia = @id_wypozyczenia
	  AND w.data_zakonczenia IS NULL;

	IF @data_rozpoczecia IS NULL
		RETURN NULL;

	SET @minuty         = DATEDIFF(MINUTE, @data_rozpoczecia, @na_chwile);
	SET @sekundy_reszta = DATEDIFF(SECOND, DATEADD(MINUTE, @minuty, @data_rozpoczecia), @na_chwile);
	IF @sekundy_reszta > 0
		SET @minuty = @minuty + 1;
	IF @minuty < 1
		SET @minuty = 1;

	RETURN @minuty * @stawka;
END
GO

--PROCEDURY RAPORTOWE

--usp_RaportPrzychodowOkres
--Dzienny przychod z zakonczonych wypozyczen w zadanym okresie.
--Zwraca jeden zbior wynikow: (dzien, liczba_wypozyczen, przychod).

IF OBJECT_ID('dbo.usp_RaportPrzychodowOkres', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_RaportPrzychodowOkres;
GO

CREATE PROCEDURE usp_RaportPrzychodowOkres
	@data_od	DATETIME2(0),
	@data_do	DATETIME2(0)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT CAST(w.data_zakonczenia AS DATE)		AS dzien,
	       COUNT(*)								AS liczba_wypozyczen,
	       SUM(w.oplata)						AS przychod
	FROM dbo.Wypozyczenie w
	WHERE w.data_zakonczenia IS NOT NULL
	  AND w.data_zakonczenia >= @data_od
	  AND w.data_zakonczenia <  @data_do
	GROUP BY CAST(w.data_zakonczenia AS DATE)
	ORDER BY dzien;
END
GO

--usp_RaportPojazdu
--Karta pojazdu: dane podstawowe + agregaty z historii wypozyczen.
--Zwraca dwa zbiory wynikow:
--1) dane pojazdu + nazwa aktualnej stacji (LEFT JOIN bo pojazd
--	   wypozyczony ma id_stacji = NULL),
--2) statystyki: liczba zakonczonych wypozyczen, suma minut, suma oplat.

IF OBJECT_ID('dbo.usp_RaportPojazdu', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_RaportPojazdu;
GO

CREATE PROCEDURE usp_RaportPojazdu
	@id_pojazdu	INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT p.id_pojazdu,
	       p.typ,
	       p.numer_seryjny,
	       p.status,
	       p.stan_techniczny,
	       s.id_stacji		AS id_stacji_aktualnej,
	       s.nazwa			AS nazwa_stacji_aktualnej
	FROM dbo.Pojazd p
	LEFT JOIN dbo.Stacja s ON s.id_stacji = p.id_stacji
	WHERE p.id_pojazdu = @id_pojazdu;

	SELECT COUNT(*)												AS liczba_wypozyczen,
	       SUM(DATEDIFF(MINUTE, data_rozpoczecia, data_zakonczenia))
	                                                            AS suma_minut,
	       SUM(oplata)											AS suma_przychodu
	FROM dbo.Wypozyczenie
	WHERE id_pojazdu = @id_pojazdu
	  AND data_zakonczenia IS NOT NULL;
END
GO

--usp_RaportUzytkownika
--Karta uzytkownika: dane + agregaty wypozyczen + suma doladowan.
--Zwraca trzy zbiory wynikow:
--	1) dane uzytkownika (z saldem),
--	2) agregaty zakonczonych wypozyczen (liczba, suma minut, suma oplat),
--	3) suma doladowan.

IF OBJECT_ID('dbo.usp_RaportUzytkownika', 'P') IS NOT NULL
	DROP PROCEDURE dbo.usp_RaportUzytkownika;
GO

CREATE PROCEDURE usp_RaportUzytkownika
	@id_uzytkownika	INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT id_uzytkownika,
	       imie,
	       nazwisko,
	       email,
	       telefon,
	       saldo
	FROM dbo.Uzytkownik
	WHERE id_uzytkownika = @id_uzytkownika;

	SELECT COUNT(*)												AS liczba_wypozyczen,
	       SUM(DATEDIFF(MINUTE, data_rozpoczecia, data_zakonczenia))
	                                                            AS suma_minut,
	       SUM(oplata)											AS suma_oplat
	FROM dbo.Wypozyczenie
	WHERE id_uzytkownika = @id_uzytkownika
	  AND data_zakonczenia IS NOT NULL;

	SELECT COALESCE(SUM(kwota), 0)								AS suma_doladowan,
	       COUNT(*)												AS liczba_doladowan
	FROM dbo.Doladowanie
	WHERE id_uzytkownika = @id_uzytkownika;
END
GO

PRINT 'Etap 9: 3 indeksy, 4 widoki, 2 funkcje, 3 procedury raportowe utworzone pomyslnie.';
GO

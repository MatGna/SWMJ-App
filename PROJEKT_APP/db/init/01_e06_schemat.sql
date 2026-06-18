--Etap 6 - System wynajmu miejskich jednosladow
--Tworzy baze WynajemJednosladow wraz ze schematem (6 tabel,
--klucze, ograniczenia, indeksy). Skrypt jest idempotentny -
--mozna go uruchamiac wielokrotnie, za kazdym razem powstaje
--swieza baza.

USE master;
GO

IF DB_ID('WynajemJednosladow') IS NOT NULL
BEGIN
	ALTER DATABASE WynajemJednosladow SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE WynajemJednosladow;
END
GO

CREATE DATABASE WynajemJednosladow
COLLATE Polish_CI_AS;
GO

ALTER DATABASE WynajemJednosladow SET RECOVERY SIMPLE;
GO

USE WynajemJednosladow;
GO


--Tabela 1: UZYTKOWNIK
CREATE TABLE Uzytkownik (
	id_uzytkownika	INT				IDENTITY(1,1)	NOT NULL,
	imie			NVARCHAR(50)					NOT NULL,
	nazwisko		NVARCHAR(50)					NOT NULL,
	email			NVARCHAR(100)					NOT NULL,
	telefon			NVARCHAR(15)					NOT NULL,
	saldo			DECIMAL(10, 2)					NOT NULL	CONSTRAINT DF_Uzytkownik_saldo DEFAULT (0),

	CONSTRAINT PK_Uzytkownik			PRIMARY KEY (id_uzytkownika),
	CONSTRAINT UQ_Uzytkownik_email		UNIQUE		(email),
	CONSTRAINT CK_Uzytkownik_imie		CHECK		(LEN(imie)     BETWEEN 1 AND 50),
	CONSTRAINT CK_Uzytkownik_nazwisko	CHECK		(LEN(nazwisko) BETWEEN 1 AND 50),
	CONSTRAINT CK_Uzytkownik_email		CHECK		(email LIKE '%_@_%.__%' AND LEN(email) <= 100),
	CONSTRAINT CK_Uzytkownik_telefon	CHECK		(LEN(telefon) BETWEEN 9 AND 15
														AND telefon NOT LIKE '%[^0-9+]%'),
	CONSTRAINT CK_Uzytkownik_saldo		CHECK		(saldo >= 0)
);
GO

--Tabela 2: STACJA  (utworzona przed POJAZD ze wzgledu na FK)
CREATE TABLE Stacja (
	id_stacji		INT				IDENTITY(1,1)	NOT NULL,
	nazwa			NVARCHAR(100)					NOT NULL,
	adres			NVARCHAR(200)					NOT NULL,
	pojemnosc		INT								NOT NULL,

	CONSTRAINT PK_Stacja				PRIMARY KEY (id_stacji),
	CONSTRAINT CK_Stacja_nazwa			CHECK		(LEN(nazwa) BETWEEN 1 AND 100),
	CONSTRAINT CK_Stacja_adres			CHECK		(LEN(adres) BETWEEN 1 AND 200),
	CONSTRAINT CK_Stacja_pojemnosc		CHECK		(pojemnosc > 0)
);
GO

--Tabela 3: POJAZD
CREATE TABLE Pojazd (
	id_pojazdu		INT				IDENTITY(1,1)	NOT NULL,
	typ				NVARCHAR(20)					NOT NULL,
	numer_seryjny	NVARCHAR(30)					NOT NULL,
	status			NVARCHAR(20)					NOT NULL,
	stan_techniczny	NVARCHAR(20)					NOT NULL,
	id_stacji		INT									NULL,

	CONSTRAINT PK_Pojazd				PRIMARY KEY (id_pojazdu),
	CONSTRAINT UQ_Pojazd_numer_seryjny	UNIQUE		(numer_seryjny),
	CONSTRAINT CK_Pojazd_typ			CHECK		(typ IN (N'rower', N'hulajnoga')),
	CONSTRAINT CK_Pojazd_numer_seryjny	CHECK		(LEN(numer_seryjny) BETWEEN 5 AND 30),
	CONSTRAINT CK_Pojazd_status			CHECK		(status IN (N'dostepny', N'wypozyczony', N'w serwisie', N'do zadokowania')),
	CONSTRAINT CK_Pojazd_stan_techn		CHECK		(stan_techniczny IN (N'sprawny', N'uszkodzony')),
	CONSTRAINT FK_Pojazd_Stacja			FOREIGN KEY (id_stacji)
											REFERENCES Stacja(id_stacji)
											ON DELETE NO ACTION
											ON UPDATE NO ACTION
);
GO

--Tabela 4: CENNIK
CREATE TABLE Cennik (
	id_cennika			INT			IDENTITY(1,1)	NOT NULL,
	typ_pojazdu			NVARCHAR(20)				NOT NULL,
	stawka_za_minute	DECIMAL(10, 2)				NOT NULL,
	data_od				DATETIME2(0)				NOT NULL,
	data_do				DATETIME2(0)					NULL,

	CONSTRAINT PK_Cennik				PRIMARY KEY (id_cennika),
	CONSTRAINT UQ_Cennik_typ_dataod		UNIQUE		(typ_pojazdu, data_od),
	CONSTRAINT CK_Cennik_typ			CHECK		(typ_pojazdu IN (N'rower', N'hulajnoga')),
	CONSTRAINT CK_Cennik_stawka			CHECK		(stawka_za_minute > 0),
	CONSTRAINT CK_Cennik_daty			CHECK		(data_do IS NULL OR data_do > data_od)
);
GO

--Tabela 5: WYPOZYCZENIE
CREATE TABLE Wypozyczenie (
	id_wypozyczenia			INT			IDENTITY(1,1)	NOT NULL,
	data_rozpoczecia		DATETIME2(0)				NOT NULL,
	data_zakonczenia		DATETIME2(0)					NULL,
	oplata					DECIMAL(10, 2)					NULL,
	koncowa_szerokosc		DECIMAL(9, 6)					NULL,
	koncowa_dlugosc			DECIMAL(9, 6)					NULL,
	id_uzytkownika			INT							NOT NULL,
	id_pojazdu				INT							NOT NULL,
	id_cennika				INT							NOT NULL,
	id_stacji_startowej		INT							NOT NULL,
	id_stacji_koncowej		INT								NULL,

	CONSTRAINT PK_Wypozyczenie					PRIMARY KEY (id_wypozyczenia),

	CONSTRAINT CK_Wypozyczenie_oplata			CHECK (oplata IS NULL OR oplata >= 0),
	CONSTRAINT CK_Wypozyczenie_szerokosc		CHECK (koncowa_szerokosc IS NULL
														OR koncowa_szerokosc BETWEEN -90  AND  90),
	CONSTRAINT CK_Wypozyczenie_dlugosc			CHECK (koncowa_dlugosc IS NULL
														OR koncowa_dlugosc   BETWEEN -180 AND 180),

	--ZPB2: data zakonczenia nie wczesniej niz rozpoczecia
	CONSTRAINT CK_Wypozyczenie_daty				CHECK (data_zakonczenia IS NULL
														OR data_zakonczenia >= data_rozpoczecia),

	--ZPB3: oplata moze byc wypelniona tylko gdy wypozyczenie zakonczone
	--(oplata IS NOT NULL  =>  data_zakonczenia IS NOT NULL)
	CONSTRAINT CK_Wypozyczenie_oplata_konce		CHECK (oplata IS NULL OR data_zakonczenia IS NOT NULL),

	--ZPD19/20: jesli sa wspolrzedne, to obie naraz
	CONSTRAINT CK_Wypozyczenie_wspolrzedne		CHECK ((koncowa_szerokosc IS NULL AND koncowa_dlugosc IS NULL)
														OR (koncowa_szerokosc IS NOT NULL AND koncowa_dlugosc IS NOT NULL)),

	--ZPB8 (czesc deklaratywna): zwrot ma albo stacje koncowa, 
	--albo wspolrzedne, nigdy oba naraz
	CONSTRAINT CK_Wypozyczenie_zwrot			CHECK (data_zakonczenia IS NULL
														OR (id_stacji_koncowej IS NOT NULL  AND koncowa_szerokosc IS NULL)
														OR (id_stacji_koncowej IS NULL      AND koncowa_szerokosc IS NOT NULL)),

	CONSTRAINT FK_Wypozyczenie_Uzytkownik	FOREIGN KEY (id_uzytkownika)
												REFERENCES Uzytkownik(id_uzytkownika)
												ON DELETE NO ACTION
												ON UPDATE NO ACTION,
	CONSTRAINT FK_Wypozyczenie_Pojazd		FOREIGN KEY (id_pojazdu)
												REFERENCES Pojazd(id_pojazdu)
												ON DELETE NO ACTION
												ON UPDATE NO ACTION,
	CONSTRAINT FK_Wypozyczenie_Cennik		FOREIGN KEY (id_cennika)
												REFERENCES Cennik(id_cennika)
												ON DELETE NO ACTION
												ON UPDATE NO ACTION,
	CONSTRAINT FK_Wypozyczenie_StacjaStart	FOREIGN KEY (id_stacji_startowej)
												REFERENCES Stacja(id_stacji)
												ON DELETE NO ACTION
												ON UPDATE NO ACTION,
	CONSTRAINT FK_Wypozyczenie_StacjaKoniec	FOREIGN KEY (id_stacji_koncowej)
												REFERENCES Stacja(id_stacji)
												ON DELETE NO ACTION
												ON UPDATE NO ACTION
);
GO

--Tabela 6: DOLADOWANIE
CREATE TABLE Doladowanie (
	id_doladowania	INT				IDENTITY(1,1)	NOT NULL,
	kwota			DECIMAL(10, 2)					NOT NULL,
	data			DATETIME2(0)					NOT NULL,
	id_uzytkownika	INT								NOT NULL,

	CONSTRAINT PK_Doladowanie			PRIMARY KEY (id_doladowania),
	CONSTRAINT CK_Doladowanie_kwota		CHECK		(kwota > 0),
	CONSTRAINT FK_Doladowanie_Uzytkownik FOREIGN KEY (id_uzytkownika)
											REFERENCES Uzytkownik(id_uzytkownika)
											ON DELETE NO ACTION
											ON UPDATE NO ACTION
);
GO


--Indeksy pomocnicze (przyspieszaja zapytania historyczne i FK)
CREATE INDEX IX_Wypozyczenie_uzytkownik	ON Wypozyczenie(id_uzytkownika);
CREATE INDEX IX_Wypozyczenie_pojazd		ON Wypozyczenie(id_pojazdu);
CREATE INDEX IX_Wypozyczenie_cennik		ON Wypozyczenie(id_cennika);
CREATE INDEX IX_Wypozyczenie_st_start	ON Wypozyczenie(id_stacji_startowej);
CREATE INDEX IX_Wypozyczenie_st_koniec	ON Wypozyczenie(id_stacji_koncowej);
CREATE INDEX IX_Doladowanie_uzytkownik	ON Doladowanie(id_uzytkownika);
CREATE INDEX IX_Pojazd_stacja			ON Pojazd(id_stacji);
GO


PRINT 'Baza WynajemJednosladow utworzona pomyslnie.';
GO

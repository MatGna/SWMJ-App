using WynajemApp.Models;

namespace WynajemApp.Data;

/// <summary>
/// Tymczasowe zrodlo danych - w pamieci. Pozniej zostanie zastapione
/// implementacja laczaca sie z Microsoft SQL Server.
/// </summary>
public class MockDataRepository : IDataRepository
{
    private readonly List<Uzytkownik> _uzytkownicy = new()
    {
        new() { IdUzytkownika = 1, Imie = "Anna",   Nazwisko = "Kowalska",   Email = "anna.k@example.com",   Telefon = "+48500111222", Saldo = 25.50m },
        new() { IdUzytkownika = 2, Imie = "Piotr",  Nazwisko = "Nowak",      Email = "piotr.n@example.com",  Telefon = "+48500333444", Saldo = 12.00m },
        new() { IdUzytkownika = 3, Imie = "Marta",  Nazwisko = "Wisniewska", Email = "marta.w@example.com",  Telefon = "+48500555666", Saldo = 0.00m },
        new() { IdUzytkownika = 4, Imie = "Tomasz", Nazwisko = "Zielinski",  Email = "tomasz.z@example.com", Telefon = "+48500777888", Saldo = 78.20m },
    };

    private readonly List<Stacja> _stacje = new()
    {
        new() { IdStacji = 1, Nazwa = "Rynek",        Adres = "Plac Wolnosci 1, Cluj",  Pojemnosc = 20 },
        new() { IdStacji = 2, Nazwa = "Dworzec",      Adres = "ul. Kolejowa 5, Cluj",   Pojemnosc = 15 },
        new() { IdStacji = 3, Nazwa = "Park Centralny", Adres = "Aleja Parkowa 12, Cluj", Pojemnosc = 30 },
    };

    private readonly List<Pojazd> _pojazdy = new()
    {
        new() { IdPojazdu = 1, Typ = "rower",     NumerSeryjny = "ROW-0001", Status = "dostepny",       StanTechniczny = "sprawny",   IdStacji = 1 },
        new() { IdPojazdu = 2, Typ = "rower",     NumerSeryjny = "ROW-0002", Status = "wypozyczony",    StanTechniczny = "sprawny",   IdStacji = null },
        new() { IdPojazdu = 3, Typ = "hulajnoga", NumerSeryjny = "HUL-0001", Status = "dostepny",       StanTechniczny = "sprawny",   IdStacji = 2 },
        new() { IdPojazdu = 4, Typ = "hulajnoga", NumerSeryjny = "HUL-0002", Status = "w serwisie",     StanTechniczny = "uszkodzony",IdStacji = null },
        new() { IdPojazdu = 5, Typ = "rower",     NumerSeryjny = "ROW-0003", Status = "do zadokowania", StanTechniczny = "sprawny",   IdStacji = null },
    };

    private readonly List<Cennik> _cennik = new()
    {
        new() { IdCennika = 1, TypPojazdu = "rower",     StawkaZaMinute = 0.30m, DataOd = new DateTime(2026, 1, 1),  DataDo = null },
        new() { IdCennika = 2, TypPojazdu = "hulajnoga", StawkaZaMinute = 0.50m, DataOd = new DateTime(2026, 1, 1),  DataDo = null },
        new() { IdCennika = 3, TypPojazdu = "rower",     StawkaZaMinute = 0.25m, DataOd = new DateTime(2025, 6, 1),  DataDo = new DateTime(2025, 12, 31) },
    };

    private readonly List<Wypozyczenie> _wypozyczenia = new()
    {
        new() { IdWypozyczenia = 1, DataRozpoczecia = new DateTime(2026, 4, 28, 10, 15, 0), DataZakonczenia = new DateTime(2026, 4, 28, 10, 47, 0), Oplata = 9.60m,  IdUzytkownika = 1, IdPojazdu = 1, IdCennika = 1, IdStacjiStartowej = 1, IdStacjiKoncowej = 2 },
        new() { IdWypozyczenia = 2, DataRozpoczecia = new DateTime(2026, 4, 30,  9,  0, 0), DataZakonczenia = null,                                  Oplata = null,    IdUzytkownika = 2, IdPojazdu = 2, IdCennika = 1, IdStacjiStartowej = 2, IdStacjiKoncowej = null },
        new() { IdWypozyczenia = 3, DataRozpoczecia = new DateTime(2026, 4, 29, 14, 20, 0), DataZakonczenia = new DateTime(2026, 4, 29, 15,  5, 0), Oplata = 22.50m, IdUzytkownika = 4, IdPojazdu = 3, IdCennika = 2, IdStacjiStartowej = 3, IdStacjiKoncowej = 1 },
    };

    private readonly List<Doladowanie> _doladowania = new()
    {
        new() { IdDoladowania = 1, Kwota = 50.00m, Data = new DateTime(2026, 4, 27, 18,  0, 0), IdUzytkownika = 1 },
        new() { IdDoladowania = 2, Kwota = 30.00m, Data = new DateTime(2026, 4, 28,  8, 30, 0), IdUzytkownika = 2 },
        new() { IdDoladowania = 3, Kwota = 100.00m, Data = new DateTime(2026, 4, 25, 12,  0, 0), IdUzytkownika = 4 },
    };

    public IEnumerable<Uzytkownik>   PobierzUzytkownikow() => _uzytkownicy;
    public IEnumerable<Pojazd>       PobierzPojazdy()      => _pojazdy;
    public IEnumerable<Stacja>       PobierzStacje()       => _stacje;
    public IEnumerable<Wypozyczenie> PobierzWypozyczenia() => _wypozyczenia;
    public IEnumerable<Cennik>       PobierzCennik()       => _cennik;
    public IEnumerable<Doladowanie>  PobierzDoladowania()  => _doladowania;
}

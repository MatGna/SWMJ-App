using WynajemApp.Models;

namespace WynajemApp.Data;

/// <summary>
/// Interfejs repozytorium - kontrakt na dostep do danych.
/// Pozniej dodamy implementacje SqlServerRepository (Microsoft.Data.SqlClient),
/// na razie aplikacja dziala na MockDataRepository z danymi w pamieci.
/// </summary>
public interface IDataRepository
{
    IEnumerable<Uzytkownik> PobierzUzytkownikow();
    IEnumerable<Pojazd> PobierzPojazdy();
    IEnumerable<Stacja> PobierzStacje();
    IEnumerable<Wypozyczenie> PobierzWypozyczenia();
    IEnumerable<Cennik> PobierzCennik();
    IEnumerable<Doladowanie> PobierzDoladowania();
}

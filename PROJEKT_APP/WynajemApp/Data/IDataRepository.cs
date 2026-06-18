using WynajemApp.Models;

namespace WynajemApp.Data;

/// <summary>
/// Interfejs repozytorium - kontrakt na dostep do danych.
/// Dwie implementacje: MockDataRepository (in-memory, do testow UI bez bazy)
/// oraz SqlServerRepository (laczy sie z baza WynajemJednosladow).
/// Wybor implementacji w AppServices wg konfiguracji (appsettings.json).
/// </summary>
public interface IDataRepository
{
    // Odczyty (zakladki w UI)
    IEnumerable<Uzytkownik> PobierzUzytkownikow();
    IEnumerable<Pojazd> PobierzPojazdy();
    IEnumerable<Stacja> PobierzStacje();
    IEnumerable<Wypozyczenie> PobierzWypozyczenia();
    IEnumerable<Cennik> PobierzCennik();
    IEnumerable<Doladowanie> PobierzDoladowania();

    // Akcje operacyjne (mapuja na procedury z etapu 8).
    // Rzucaja wyjatek z numerem bledu (50001..50007) gdy trigger/procedura
    // odrzuci operacje - to ten sam mechanizm co testy z e10.
    void Doladuj(int idUzytkownika, decimal kwota);
    int RozpocznijWypozyczenie(int idUzytkownika, int idPojazdu, int idCennika, int idStacjiStartowej);
    void ZakonczWypozyczenie(int idWypozyczenia, int? idStacjiKoncowej, double? lat, double? lng);

    // Czyste CRUD (INSERT / UPDATE / DELETE). Walidacje wymuszane przez
    // triggery z e08 (kody bledow 50001 / 50006) leca jako SqlException.
    int  DodajUzytkownika(string imie, string nazwisko, string email, string telefon);
    void EdytujUzytkownika(int id, string imie, string nazwisko, string email, string telefon);
    void UsunUzytkownika(int id);

    int  DodajPojazd(string typ, string numerSeryjny, string status, string stanTechniczny, int? idStacji);
    void ZmienStatusPojazdu(int idPojazdu, string status, int? idStacji);

    int  DodajStacje(string nazwa, string adres, int pojemnosc);

    int  DodajCennik(string typPojazdu, decimal stawkaZaMinute, DateTime dataOd, DateTime? dataDo);
}

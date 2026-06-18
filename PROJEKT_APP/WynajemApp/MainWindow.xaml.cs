using System.Windows;
using Microsoft.Data.SqlClient;
using WynajemApp.Dialogs;
using WynajemApp.Models;

namespace WynajemApp;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        ZaladujDane();
    }

    private void ZaladujDane()
    {
        var repo = AppServices.Repository;

        GridUzytkownicy.ItemsSource    = repo.PobierzUzytkownikow();
        GridPojazdy.ItemsSource        = repo.PobierzPojazdy();
        GridStacje.ItemsSource         = repo.PobierzStacje();
        GridWypozyczenia.ItemsSource   = repo.PobierzWypozyczenia();
        GridCennik.ItemsSource         = repo.PobierzCennik();
        GridDoladowania.ItemsSource    = repo.PobierzDoladowania();

        StatusText.Text = $"Dane zaladowane (zrodlo: {AppServices.ZrodloDanych})";
    }

    private void Doladuj_Click(object sender, RoutedEventArgs e)
    {
        var uzytk = AppServices.Repository.PobierzUzytkownikow().ToList();
        var wynik = AkcjeDialogs.PokazDoladuj(this, uzytk);
        if (wynik == null) return;

        try
        {
            AppServices.Repository.Doladuj(wynik.IdUzytkownika, wynik.Kwota);
            MessageBox.Show(this,
                $"Doladowano {wynik.Kwota:F2} PLN dla uzytkownika #{wynik.IdUzytkownika}.",
                "Sukces", MessageBoxButton.OK, MessageBoxImage.Information);
            ZaladujDane();
        }
        catch (Exception ex) { PokazBlad(ex); }
    }

    private void Rozpocznij_Click(object sender, RoutedEventArgs e)
    {
        var uzytk    = AppServices.Repository.PobierzUzytkownikow().ToList();
        var pojazdy  = AppServices.Repository.PobierzPojazdy().ToList();
        var cenniki  = AppServices.Repository.PobierzCennik().ToList();
        var stacje   = AppServices.Repository.PobierzStacje().ToList();

        var wynik = AkcjeDialogs.PokazRozpocznij(this, uzytk, pojazdy, cenniki, stacje);
        if (wynik == null) return;

        try
        {
            var idWyp = AppServices.Repository.RozpocznijWypozyczenie(
                wynik.IdUzytkownika, wynik.IdPojazdu, wynik.IdCennika, wynik.IdStacjiStartowej);
            MessageBox.Show(this,
                $"Rozpoczeto wypozyczenie #{idWyp} (pojazd #{wynik.IdPojazdu}).",
                "Sukces", MessageBoxButton.OK, MessageBoxImage.Information);
            ZaladujDane();
        }
        catch (Exception ex) { PokazBlad(ex); }
    }

    private void Zakoncz_Click(object sender, RoutedEventArgs e)
    {
        var wszystkie = AppServices.Repository.PobierzWypozyczenia().ToList();
        var aktywne   = wszystkie.Where(w => w.DataZakonczenia == null).ToList();
        var uzytk     = AppServices.Repository.PobierzUzytkownikow().ToList();
        var pojazdy   = AppServices.Repository.PobierzPojazdy().ToList();
        var stacje    = AppServices.Repository.PobierzStacje().ToList();

        var wynik = AkcjeDialogs.PokazZakoncz(this, aktywne, uzytk, pojazdy, stacje);
        if (wynik == null) return;

        try
        {
            AppServices.Repository.ZakonczWypozyczenie(
                wynik.IdWypozyczenia, wynik.IdStacjiKoncowej, wynik.Lat, wynik.Lng);
            MessageBox.Show(this,
                $"Zakonczono wypozyczenie #{wynik.IdWypozyczenia}.",
                "Sukces", MessageBoxButton.OK, MessageBoxImage.Information);
            ZaladujDane();
        }
        catch (Exception ex) { PokazBlad(ex); }
    }

    private void PokazBlad(Exception ex)
    {
        var msg = ex is SqlException sql
            ? $"Blad bazy {sql.Number}: {sql.Message}"
            : ex.Message;

        MessageBox.Show(this, msg, "Operacja odrzucona", MessageBoxButton.OK, MessageBoxImage.Warning);
    }

    // -----------------------------------------------------------------
    // CRUD (INSERT/UPDATE/DELETE) - walidacja po stronie bazy
    // -----------------------------------------------------------------

    private void DodajUzytk_Click(object sender, RoutedEventArgs e)
    {
        var wynik = AkcjeDialogs.PokazUzytkownik(this, "Nowy uzytkownik");
        if (wynik == null) return;
        try
        {
            var id = AppServices.Repository.DodajUzytkownika(wynik.Imie, wynik.Nazwisko, wynik.Email, wynik.Telefon);
            MessageBox.Show(this, $"Dodano uzytkownika #{id}.", "Sukces", MessageBoxButton.OK, MessageBoxImage.Information);
            ZaladujDane();
        }
        catch (Exception ex) { PokazBlad(ex); }
    }

    private void EdytujUzytk_Click(object sender, RoutedEventArgs e)
    {
        if (GridUzytkownicy.SelectedItem is not Uzytkownik u)
        { MessageBox.Show(this, "Zaznacz uzytkownika w tabeli.", "Brak wyboru", MessageBoxButton.OK, MessageBoxImage.Information); return; }

        var wynik = AkcjeDialogs.PokazUzytkownik(this, $"Edycja uzytkownika #{u.IdUzytkownika}", u);
        if (wynik == null) return;
        try
        {
            AppServices.Repository.EdytujUzytkownika(u.IdUzytkownika, wynik.Imie, wynik.Nazwisko, wynik.Email, wynik.Telefon);
            MessageBox.Show(this, $"Zaktualizowano uzytkownika #{u.IdUzytkownika}.", "Sukces", MessageBoxButton.OK, MessageBoxImage.Information);
            ZaladujDane();
        }
        catch (Exception ex) { PokazBlad(ex); }
    }

    private void UsunUzytk_Click(object sender, RoutedEventArgs e)
    {
        if (GridUzytkownicy.SelectedItem is not Uzytkownik u)
        { MessageBox.Show(this, "Zaznacz uzytkownika w tabeli.", "Brak wyboru", MessageBoxButton.OK, MessageBoxImage.Information); return; }

        var r = MessageBox.Show(this,
            $"Usunac uzytkownika #{u.IdUzytkownika} {u.Imie} {u.Nazwisko}?\n\nUWAGA: jezeli ma wypozyczenia/doladowania, baza odrzuci operacje (klucz obcy).",
            "Potwierdzenie", MessageBoxButton.YesNo, MessageBoxImage.Warning);
        if (r != MessageBoxResult.Yes) return;
        try
        {
            AppServices.Repository.UsunUzytkownika(u.IdUzytkownika);
            MessageBox.Show(this, "Usunieto.", "Sukces", MessageBoxButton.OK, MessageBoxImage.Information);
            ZaladujDane();
        }
        catch (Exception ex) { PokazBlad(ex); }
    }

    private void DodajPojazd_Click(object sender, RoutedEventArgs e)
    {
        var stacje = AppServices.Repository.PobierzStacje().ToList();
        var wynik = AkcjeDialogs.PokazDodajPojazd(this, stacje);
        if (wynik == null) return;
        try
        {
            var id = AppServices.Repository.DodajPojazd(wynik.Typ, wynik.NumerSeryjny, wynik.Status, wynik.StanTechniczny, wynik.IdStacji);
            MessageBox.Show(this, $"Dodano pojazd #{id}.", "Sukces", MessageBoxButton.OK, MessageBoxImage.Information);
            ZaladujDane();
        }
        catch (Exception ex) { PokazBlad(ex); }
    }

    private void ZmienStatus_Click(object sender, RoutedEventArgs e)
    {
        if (GridPojazdy.SelectedItem is not Pojazd p)
        { MessageBox.Show(this, "Zaznacz pojazd w tabeli.", "Brak wyboru", MessageBoxButton.OK, MessageBoxImage.Information); return; }

        var stacje = AppServices.Repository.PobierzStacje().ToList();
        var wynik = AkcjeDialogs.PokazZmienStatus(this, p, stacje);
        if (wynik == null) return;
        try
        {
            AppServices.Repository.ZmienStatusPojazdu(p.IdPojazdu, wynik.Status, wynik.IdStacji);
            MessageBox.Show(this, $"Zaktualizowano pojazd #{p.IdPojazdu}.", "Sukces", MessageBoxButton.OK, MessageBoxImage.Information);
            ZaladujDane();
        }
        catch (Exception ex) { PokazBlad(ex); }
    }

    private void DodajStacje_Click(object sender, RoutedEventArgs e)
    {
        var wynik = AkcjeDialogs.PokazDodajStacje(this);
        if (wynik == null) return;
        try
        {
            var id = AppServices.Repository.DodajStacje(wynik.Nazwa, wynik.Adres, wynik.Pojemnosc);
            MessageBox.Show(this, $"Dodano stacje #{id}.", "Sukces", MessageBoxButton.OK, MessageBoxImage.Information);
            ZaladujDane();
        }
        catch (Exception ex) { PokazBlad(ex); }
    }

    private void DodajCennik_Click(object sender, RoutedEventArgs e)
    {
        var wynik = AkcjeDialogs.PokazDodajCennik(this);
        if (wynik == null) return;
        try
        {
            var id = AppServices.Repository.DodajCennik(wynik.TypPojazdu, wynik.StawkaZaMinute, wynik.DataOd, wynik.DataDo);
            MessageBox.Show(this, $"Dodano stawke #{id}.", "Sukces", MessageBoxButton.OK, MessageBoxImage.Information);
            ZaladujDane();
        }
        catch (Exception ex) { PokazBlad(ex); }
    }

    private void NotImplemented_Click(object sender, RoutedEventArgs e)
    {
        MessageBox.Show(
            "Funkcja zostanie wlaczona po podpieciu bazy SQL Server.",
            "Informacja",
            MessageBoxButton.OK,
            MessageBoxImage.Information);
    }
}

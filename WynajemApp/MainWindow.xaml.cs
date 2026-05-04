using System.Windows;

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

        StatusText.Text = "Dane zaladowane (zrodlo: MockDataRepository - dane w pamieci)";
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

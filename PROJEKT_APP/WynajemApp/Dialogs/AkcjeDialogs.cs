using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using WynajemApp.Models;

namespace WynajemApp.Dialogs;

/// <summary>
/// Proste okna dialogowe do trzech akcji operacyjnych (doladuj, rozpocznij,
/// zakoncz wypozyczenie). Zbudowane w kodzie zamiast w XAML zeby trzymac
/// calosc w jednym miejscu - to proste formularze, nie potrzebuja stylowania.
/// </summary>
public static class AkcjeDialogs
{
    // --------------------------------------------------------------------
    // 1) DOLADUJ
    // --------------------------------------------------------------------
    public sealed class DoladujWynik
    {
        public int IdUzytkownika { get; init; }
        public decimal Kwota { get; init; }
    }

    public static DoladujWynik? PokazDoladuj(Window owner, IList<Uzytkownik> uzytkownicy)
    {
        var cmbUzytk = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        foreach (var u in uzytkownicy)
            cmbUzytk.Items.Add(new ComboItem<Uzytkownik>(u, $"{u.Imie} {u.Nazwisko}  (saldo {u.Saldo:F2} PLN)"));
        cmbUzytk.SelectedIndex = 0;

        var txtKwota = new TextBox { Margin = new Thickness(0, 0, 0, 12), Text = "50,00" };

        var (ok, win) = BudujDialog(owner, "Nowe doladowanie", 380,
            ("Uzytkownik:", cmbUzytk),
            ("Kwota (PLN):", txtKwota));

        DoladujWynik? wynik = null;
        ok.Click += (_, _) =>
        {
            if (cmbUzytk.SelectedItem is not ComboItem<Uzytkownik> sel)
            {
                MessageBox.Show(win, "Wybierz uzytkownika.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            if (!TryParseKwota(txtKwota.Text, out var kwota) || kwota <= 0)
            {
                MessageBox.Show(win, "Kwota musi byc dodatnia (np. 50,00).", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            wynik = new DoladujWynik { IdUzytkownika = sel.Value.IdUzytkownika, Kwota = kwota };
            win.DialogResult = true;
        };

        win.ShowDialog();
        return wynik;
    }

    // --------------------------------------------------------------------
    // 2) ROZPOCZNIJ WYPOZYCZENIE
    // --------------------------------------------------------------------
    public sealed class RozpocznijWynik
    {
        public int IdUzytkownika { get; init; }
        public int IdPojazdu { get; init; }
        public int IdCennika { get; init; }
        public int IdStacjiStartowej { get; init; }
    }

    public static RozpocznijWynik? PokazRozpocznij(
        Window owner,
        IList<Uzytkownik> uzytkownicy,
        IList<Pojazd> pojazdy,
        IList<Cennik> cenniki,
        IList<Stacja> stacje)
    {
        var cmbUzytk = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        foreach (var u in uzytkownicy)
            cmbUzytk.Items.Add(new ComboItem<Uzytkownik>(u, $"{u.Imie} {u.Nazwisko}  (saldo {u.Saldo:F2} PLN)"));
        cmbUzytk.SelectedIndex = 0;

        var cmbPojazd = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        foreach (var p in pojazdy.Where(p => string.Equals(p.Status, "dostepny", StringComparison.OrdinalIgnoreCase)))
            cmbPojazd.Items.Add(new ComboItem<Pojazd>(p, $"#{p.IdPojazdu} {p.Typ} {p.NumerSeryjny}  (stacja {p.IdStacji?.ToString() ?? "?"})"));
        if (cmbPojazd.Items.Count > 0) cmbPojazd.SelectedIndex = 0;

        var cmbCennik = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        foreach (var c in cenniki)
            cmbCennik.Items.Add(new ComboItem<Cennik>(c, $"#{c.IdCennika} {c.TypPojazdu}  {c.StawkaZaMinute:F2} PLN/min  (od {c.DataOd:d})"));
        if (cmbCennik.Items.Count > 0) cmbCennik.SelectedIndex = 0;

        var cmbStacja = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        foreach (var s in stacje)
            cmbStacja.Items.Add(new ComboItem<Stacja>(s, $"#{s.IdStacji} {s.Nazwa}  ({s.Adres})"));
        if (cmbStacja.Items.Count > 0) cmbStacja.SelectedIndex = 0;

        // Autoustawienie stacji startowej zgodnie z lokalizacja wybranego pojazdu
        cmbPojazd.SelectionChanged += (_, _) =>
        {
            if (cmbPojazd.SelectedItem is ComboItem<Pojazd> sp && sp.Value.IdStacji is int idS)
            {
                for (int i = 0; i < cmbStacja.Items.Count; i++)
                    if (cmbStacja.Items[i] is ComboItem<Stacja> ss && ss.Value.IdStacji == idS)
                    { cmbStacja.SelectedIndex = i; break; }
            }
        };

        var (ok, win) = BudujDialog(owner, "Nowe wypozyczenie", 460,
            ("Uzytkownik:",       cmbUzytk),
            ("Pojazd (dostepny):", cmbPojazd),
            ("Cennik:",           cmbCennik),
            ("Stacja startowa:",  cmbStacja));

        RozpocznijWynik? wynik = null;
        ok.Click += (_, _) =>
        {
            if (cmbUzytk.SelectedItem is not ComboItem<Uzytkownik> u ||
                cmbPojazd.SelectedItem is not ComboItem<Pojazd> p ||
                cmbCennik.SelectedItem is not ComboItem<Cennik> c ||
                cmbStacja.SelectedItem is not ComboItem<Stacja> s)
            {
                MessageBox.Show(win, "Uzupelnij wszystkie pola.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            wynik = new RozpocznijWynik
            {
                IdUzytkownika     = u.Value.IdUzytkownika,
                IdPojazdu         = p.Value.IdPojazdu,
                IdCennika         = c.Value.IdCennika,
                IdStacjiStartowej = s.Value.IdStacji
            };
            win.DialogResult = true;
        };

        win.ShowDialog();
        return wynik;
    }

    // --------------------------------------------------------------------
    // 3) ZAKONCZ WYPOZYCZENIE
    // --------------------------------------------------------------------
    public sealed class ZakonczWynik
    {
        public int IdWypozyczenia { get; init; }
        public int? IdStacjiKoncowej { get; init; }
        public double? Lat { get; init; }
        public double? Lng { get; init; }
    }

    public static ZakonczWynik? PokazZakoncz(
        Window owner,
        IList<Wypozyczenie> aktywne,
        IList<Uzytkownik> uzytkownicy,
        IList<Pojazd> pojazdy,
        IList<Stacja> stacje)
    {
        if (aktywne.Count == 0)
        {
            MessageBox.Show(owner, "Brak aktywnych wypozyczen do zakonczenia.", "Informacja",
                MessageBoxButton.OK, MessageBoxImage.Information);
            return null;
        }

        var cmbWyp = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        foreach (var w in aktywne)
        {
            var u = uzytkownicy.FirstOrDefault(x => x.IdUzytkownika == w.IdUzytkownika);
            var p = pojazdy.FirstOrDefault(x => x.IdPojazdu == w.IdPojazdu);
            var label = $"#{w.IdWypozyczenia} {u?.Imie} {u?.Nazwisko}  -  {p?.Typ} {p?.NumerSeryjny}  (start {w.DataRozpoczecia:g})";
            cmbWyp.Items.Add(new ComboItem<Wypozyczenie>(w, label));
        }
        cmbWyp.SelectedIndex = 0;

        var cmbStacja = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        cmbStacja.Items.Add(new ComboItem<Stacja?>(null, "(brak - zwrot poza stacja, wymagany GPS)"));
        foreach (var s in stacje)
            cmbStacja.Items.Add(new ComboItem<Stacja?>(s, $"#{s.IdStacji} {s.Nazwa}  ({s.Adres})"));
        cmbStacja.SelectedIndex = 0;

        var txtLat = new TextBox { Margin = new Thickness(0, 0, 0, 12), Text = "" };
        var txtLng = new TextBox { Margin = new Thickness(0, 0, 0, 12), Text = "" };

        var (ok, win) = BudujDialog(owner, "Zakoncz wypozyczenie", 480,
            ("Wypozyczenie:",     cmbWyp),
            ("Stacja koncowa:",   cmbStacja),
            ("Szerokosc:",        txtLat),
            ("Dlugosc:",          txtLng));

        ZakonczWynik? wynik = null;
        ok.Click += (_, _) =>
        {
            if (cmbWyp.SelectedItem is not ComboItem<Wypozyczenie> w)
            {
                MessageBox.Show(win, "Wybierz wypozyczenie.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            int? idStacjiK = null;
            if (cmbStacja.SelectedItem is ComboItem<Stacja?> sel && sel.Value is Stacja stj)
                idStacjiK = stj.IdStacji;

            double? lat = null, lng = null;
            if (!string.IsNullOrWhiteSpace(txtLat.Text))
            {
                if (!TryParseDouble(txtLat.Text, out var v) || v < -90 || v > 90)
                { MessageBox.Show(win, "Szerokosc musi byc liczba z zakresu -90..90.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning); return; }
                lat = v;
            }
            if (!string.IsNullOrWhiteSpace(txtLng.Text))
            {
                if (!TryParseDouble(txtLng.Text, out var v) || v < -180 || v > 180)
                { MessageBox.Show(win, "Dlugosc musi byc liczba z zakresu -180..180.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning); return; }
                lng = v;
            }
            if ((lat == null) != (lng == null))
            { MessageBox.Show(win, "Podaj OBA lub ZADNE pola GPS.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning); return; }

            // ZPB8: zwrot ma dokladnie jedno - stacja koncowa XOR GPS.
            bool maStacje = idStacjiK.HasValue;
            bool maGps    = lat.HasValue;
            if (maStacje && maGps)
            { MessageBox.Show(win, "Wybierz ALBO stacje koncowa, ALBO wspolrzedne GPS - nigdy oba naraz.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning); return; }
            if (!maStacje && !maGps)
            { MessageBox.Show(win, "Musisz podac stacje koncowa LUB wspolrzedne GPS (zwrot poza stacja).", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning); return; }

            wynik = new ZakonczWynik
            {
                IdWypozyczenia   = w.Value.IdWypozyczenia,
                IdStacjiKoncowej = idStacjiK,
                Lat              = lat,
                Lng              = lng
            };
            win.DialogResult = true;
        };

        win.ShowDialog();
        return wynik;
    }

    // --------------------------------------------------------------------
    // 4) UZYTKOWNIK - DODAJ / EDYTUJ
    // --------------------------------------------------------------------
    public sealed class UzytkownikWynik
    {
        public string Imie { get; init; } = "";
        public string Nazwisko { get; init; } = "";
        public string Email { get; init; } = "";
        public string Telefon { get; init; } = "";
    }

    public static UzytkownikWynik? PokazUzytkownik(Window owner, string tytul, Uzytkownik? edytowany = null)
    {
        var txtImie     = new TextBox { Margin = new Thickness(0, 0, 0, 12), Text = edytowany?.Imie ?? "" };
        var txtNazwisko = new TextBox { Margin = new Thickness(0, 0, 0, 12), Text = edytowany?.Nazwisko ?? "" };
        var txtEmail    = new TextBox { Margin = new Thickness(0, 0, 0, 12), Text = edytowany?.Email ?? "" };
        var txtTelefon  = new TextBox { Margin = new Thickness(0, 0, 0, 12), Text = edytowany?.Telefon ?? "" };

        var (ok, win) = BudujDialog(owner, tytul, 400,
            ("Imie:",     txtImie),
            ("Nazwisko:", txtNazwisko),
            ("Email:",    txtEmail),
            ("Telefon:",  txtTelefon));

        UzytkownikWynik? wynik = null;
        ok.Click += (_, _) =>
        {
            if (string.IsNullOrWhiteSpace(txtImie.Text) || string.IsNullOrWhiteSpace(txtNazwisko.Text)
                || string.IsNullOrWhiteSpace(txtEmail.Text))
            {
                MessageBox.Show(win, "Imie, nazwisko i email sa wymagane.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            if (!txtEmail.Text.Contains('@'))
            {
                MessageBox.Show(win, "Email musi zawierac '@'.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            wynik = new UzytkownikWynik
            {
                Imie     = txtImie.Text.Trim(),
                Nazwisko = txtNazwisko.Text.Trim(),
                Email    = txtEmail.Text.Trim(),
                Telefon  = txtTelefon.Text.Trim()
            };
            win.DialogResult = true;
        };

        win.ShowDialog();
        return wynik;
    }

    // --------------------------------------------------------------------
    // 5) POJAZD - DODAJ
    // --------------------------------------------------------------------
    public sealed class PojazdWynik
    {
        public string Typ { get; init; } = "";
        public string NumerSeryjny { get; init; } = "";
        public string Status { get; init; } = "";
        public string StanTechniczny { get; init; } = "";
        public int? IdStacji { get; init; }
    }

    public static PojazdWynik? PokazDodajPojazd(Window owner, IList<Stacja> stacje)
    {
        var cmbTyp = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        cmbTyp.Items.Add("rower");
        cmbTyp.Items.Add("hulajnoga");
        cmbTyp.SelectedIndex = 0;

        var txtNr = new TextBox { Margin = new Thickness(0, 0, 0, 12), Text = "" };

        var cmbStatus = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        foreach (var s in new[] { "dostepny", "wypozyczony", "w serwisie", "do zadokowania" })
            cmbStatus.Items.Add(s);
        cmbStatus.SelectedIndex = 0;

        var cmbStan = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        foreach (var s in new[] { "sprawny", "do_przegladu", "uszkodzony" })
            cmbStan.Items.Add(s);
        cmbStan.SelectedIndex = 0;

        var cmbStacja = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        cmbStacja.Items.Add(new ComboItem<Stacja?>(null, "(brak - pojazd poza stacja)"));
        foreach (var s in stacje)
            cmbStacja.Items.Add(new ComboItem<Stacja?>(s, $"#{s.IdStacji} {s.Nazwa} (poj. {s.Pojemnosc})"));
        cmbStacja.SelectedIndex = 0;

        var (ok, win) = BudujDialog(owner, "Nowy pojazd", 440,
            ("Typ:",            cmbTyp),
            ("Numer seryjny:",  txtNr),
            ("Status:",         cmbStatus),
            ("Stan techniczny:",cmbStan),
            ("Stacja:",         cmbStacja));

        PojazdWynik? wynik = null;
        ok.Click += (_, _) =>
        {
            if (string.IsNullOrWhiteSpace(txtNr.Text))
            { MessageBox.Show(win, "Numer seryjny wymagany.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning); return; }

            int? idStacji = null;
            if (cmbStacja.SelectedItem is ComboItem<Stacja?> sel && sel.Value is Stacja st)
                idStacji = st.IdStacji;

            wynik = new PojazdWynik
            {
                Typ            = (string)cmbTyp.SelectedItem,
                NumerSeryjny   = txtNr.Text.Trim(),
                Status         = (string)cmbStatus.SelectedItem,
                StanTechniczny = (string)cmbStan.SelectedItem,
                IdStacji       = idStacji
            };
            win.DialogResult = true;
        };

        win.ShowDialog();
        return wynik;
    }

    // --------------------------------------------------------------------
    // 6) POJAZD - ZMIEN STATUS
    // --------------------------------------------------------------------
    public sealed class ZmienStatusWynik
    {
        public string Status { get; init; } = "";
        public int? IdStacji { get; init; }
    }

    public static ZmienStatusWynik? PokazZmienStatus(Window owner, Pojazd pojazd, IList<Stacja> stacje)
    {
        var cmbStatus = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        foreach (var s in new[] { "dostepny", "wypozyczony", "w serwisie", "do zadokowania" })
            cmbStatus.Items.Add(s);
        cmbStatus.SelectedItem = pojazd.Status;

        var cmbStacja = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        cmbStacja.Items.Add(new ComboItem<Stacja?>(null, "(brak - poza stacja)"));
        foreach (var s in stacje)
            cmbStacja.Items.Add(new ComboItem<Stacja?>(s, $"#{s.IdStacji} {s.Nazwa} (poj. {s.Pojemnosc})"));
        cmbStacja.SelectedIndex = 0;
        if (pojazd.IdStacji is int idS)
        {
            for (int i = 1; i < cmbStacja.Items.Count; i++)
                if (cmbStacja.Items[i] is ComboItem<Stacja?> ci && ci.Value?.IdStacji == idS)
                { cmbStacja.SelectedIndex = i; break; }
        }

        var (ok, win) = BudujDialog(owner, $"Zmiana statusu pojazdu #{pojazd.IdPojazdu}", 420,
            ("Status:",  cmbStatus),
            ("Stacja:",  cmbStacja));

        ZmienStatusWynik? wynik = null;
        ok.Click += (_, _) =>
        {
            int? idStacji = null;
            if (cmbStacja.SelectedItem is ComboItem<Stacja?> sel && sel.Value is Stacja st)
                idStacji = st.IdStacji;

            wynik = new ZmienStatusWynik
            {
                Status   = (string)cmbStatus.SelectedItem,
                IdStacji = idStacji
            };
            win.DialogResult = true;
        };

        win.ShowDialog();
        return wynik;
    }

    // --------------------------------------------------------------------
    // 7) STACJA - DODAJ
    // --------------------------------------------------------------------
    public sealed class StacjaWynik
    {
        public string Nazwa { get; init; } = "";
        public string Adres { get; init; } = "";
        public int Pojemnosc { get; init; }
    }

    public static StacjaWynik? PokazDodajStacje(Window owner)
    {
        var txtNazwa = new TextBox { Margin = new Thickness(0, 0, 0, 12) };
        var txtAdres = new TextBox { Margin = new Thickness(0, 0, 0, 12) };
        var txtPoj   = new TextBox { Margin = new Thickness(0, 0, 0, 12), Text = "20" };

        var (ok, win) = BudujDialog(owner, "Nowa stacja", 420,
            ("Nazwa:",     txtNazwa),
            ("Adres:",     txtAdres),
            ("Pojemnosc:", txtPoj));

        StacjaWynik? wynik = null;
        ok.Click += (_, _) =>
        {
            if (string.IsNullOrWhiteSpace(txtNazwa.Text) || string.IsNullOrWhiteSpace(txtAdres.Text))
            { MessageBox.Show(win, "Nazwa i adres sa wymagane.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning); return; }
            if (!int.TryParse(txtPoj.Text, out var poj) || poj <= 0)
            { MessageBox.Show(win, "Pojemnosc musi byc dodatnia liczba calkowita.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning); return; }

            wynik = new StacjaWynik { Nazwa = txtNazwa.Text.Trim(), Adres = txtAdres.Text.Trim(), Pojemnosc = poj };
            win.DialogResult = true;
        };

        win.ShowDialog();
        return wynik;
    }

    // --------------------------------------------------------------------
    // 8) CENNIK - NOWA STAWKA
    // --------------------------------------------------------------------
    public sealed class CennikWynik
    {
        public string TypPojazdu { get; init; } = "";
        public decimal StawkaZaMinute { get; init; }
        public DateTime DataOd { get; init; }
        public DateTime? DataDo { get; init; }
    }

    public static CennikWynik? PokazDodajCennik(Window owner)
    {
        var cmbTyp = new ComboBox { Margin = new Thickness(0, 0, 0, 12) };
        cmbTyp.Items.Add("rower");
        cmbTyp.Items.Add("hulajnoga");
        cmbTyp.SelectedIndex = 0;

        var txtStawka = new TextBox { Margin = new Thickness(0, 0, 0, 12), Text = "0,50" };

        var dpOd = new DatePicker { Margin = new Thickness(0, 0, 0, 12), SelectedDate = DateTime.Today };
        var dpDo = new DatePicker { Margin = new Thickness(0, 0, 0, 12), SelectedDate = null };

        var (ok, win) = BudujDialog(owner, "Nowa stawka cennika", 420,
            ("Typ pojazdu:",       cmbTyp),
            ("Stawka za minute:",  txtStawka),
            ("Data od:",           dpOd),
            ("Data do (opcj.):",   dpDo));

        CennikWynik? wynik = null;
        ok.Click += (_, _) =>
        {
            if (!TryParseKwota(txtStawka.Text, out var stawka) || stawka <= 0)
            { MessageBox.Show(win, "Stawka musi byc dodatnia (np. 0,50).", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning); return; }
            if (dpOd.SelectedDate == null)
            { MessageBox.Show(win, "Data 'od' jest wymagana.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning); return; }
            if (dpDo.SelectedDate is DateTime dDo && dDo < dpOd.SelectedDate.Value)
            { MessageBox.Show(win, "Data 'do' musi byc pozniejsza niz 'od'.", "Walidacja", MessageBoxButton.OK, MessageBoxImage.Warning); return; }

            wynik = new CennikWynik
            {
                TypPojazdu     = (string)cmbTyp.SelectedItem,
                StawkaZaMinute = stawka,
                DataOd         = dpOd.SelectedDate.Value,
                DataDo         = dpDo.SelectedDate
            };
            win.DialogResult = true;
        };

        win.ShowDialog();
        return wynik;
    }

    // --------------------------------------------------------------------
    // helpery
    // --------------------------------------------------------------------
    private sealed record ComboItem<T>(T Value, string Label)
    {
        public override string ToString() => Label;
    }

    private static bool TryParseKwota(string s, out decimal v) =>
        decimal.TryParse(s, NumberStyles.Number, CultureInfo.CurrentCulture, out v)
        || decimal.TryParse(s, NumberStyles.Number, CultureInfo.InvariantCulture, out v);

    private static bool TryParseDouble(string s, out double v) =>
        double.TryParse(s, NumberStyles.Float, CultureInfo.CurrentCulture, out v)
        || double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out v);

    private static (Button ok, Window window) BudujDialog(Window owner, string tytul, double width,
        params (string label, FrameworkElement input)[] pola)
    {
        var grid = new Grid { Margin = new Thickness(20) };
        for (int i = 0; i < pola.Length; i++)
        {
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        }
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // miejsce na przyciski

        for (int i = 0; i < pola.Length; i++)
        {
            var lbl = new TextBlock { Text = pola[i].label, Margin = new Thickness(0, 0, 0, 4), FontWeight = FontWeights.SemiBold };
            Grid.SetRow(lbl, i * 2);
            grid.Children.Add(lbl);

            Grid.SetRow(pola[i].input, i * 2 + 1);
            grid.Children.Add(pola[i].input);
        }

        var ok = new Button { Content = "OK", Width = 90, Margin = new Thickness(0, 8, 8, 0), IsDefault = true };
        var cancel = new Button { Content = "Anuluj", Width = 90, Margin = new Thickness(0, 8, 0, 0), IsCancel = true };
        var stack = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
        stack.Children.Add(ok);
        stack.Children.Add(cancel);
        Grid.SetRow(stack, pola.Length * 2);
        grid.Children.Add(stack);

        var win = new Window
        {
            Title = tytul,
            Width = width,
            SizeToContent = SizeToContent.Height,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Owner = owner,
            ResizeMode = ResizeMode.NoResize,
            ShowInTaskbar = false,
            Content = grid
        };
        return (ok, win);
    }
}

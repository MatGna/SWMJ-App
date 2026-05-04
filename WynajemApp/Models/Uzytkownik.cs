namespace WynajemApp.Models;

public class Uzytkownik
{
    public int IdUzytkownika { get; set; }
    public string Imie { get; set; } = string.Empty;
    public string Nazwisko { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Telefon { get; set; } = string.Empty;
    public decimal Saldo { get; set; }
}

namespace WynajemApp.Models;

public class Doladowanie
{
    public int IdDoladowania { get; set; }
    public decimal Kwota { get; set; }
    public DateTime Data { get; set; }
    public int IdUzytkownika { get; set; }
}

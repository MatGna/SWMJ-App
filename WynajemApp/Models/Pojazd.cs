namespace WynajemApp.Models;

public class Pojazd
{
    public int IdPojazdu { get; set; }
    public string Typ { get; set; } = string.Empty;          // "rower" / "hulajnoga"
    public string NumerSeryjny { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;       // "dostepny" / "wypozyczony" / "w serwisie" / "do zadokowania"
    public string StanTechniczny { get; set; } = string.Empty;
    public int? IdStacji { get; set; }
}

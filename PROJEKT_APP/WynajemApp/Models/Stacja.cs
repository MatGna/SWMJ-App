namespace WynajemApp.Models;

public class Stacja
{
    public int IdStacji { get; set; }
    public string Nazwa { get; set; } = string.Empty;
    public string Adres { get; set; } = string.Empty;
    public int Pojemnosc { get; set; }
}

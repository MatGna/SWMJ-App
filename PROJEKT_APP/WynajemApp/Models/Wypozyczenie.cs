namespace WynajemApp.Models;

public class Wypozyczenie
{
    public int IdWypozyczenia { get; set; }
    public DateTime DataRozpoczecia { get; set; }
    public DateTime? DataZakonczenia { get; set; }
    public decimal? Oplata { get; set; }
    public double? KoncowaSzerokosc { get; set; }
    public double? KoncowaDlugosc { get; set; }
    public int IdUzytkownika { get; set; }
    public int IdPojazdu { get; set; }
    public int IdCennika { get; set; }
    public int IdStacjiStartowej { get; set; }
    public int? IdStacjiKoncowej { get; set; }
}

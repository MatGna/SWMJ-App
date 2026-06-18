namespace WynajemApp.Models;

public class Cennik
{
    public int IdCennika { get; set; }
    public string TypPojazdu { get; set; } = string.Empty;
    public decimal StawkaZaMinute { get; set; }
    public DateTime DataOd { get; set; }
    public DateTime? DataDo { get; set; }
}

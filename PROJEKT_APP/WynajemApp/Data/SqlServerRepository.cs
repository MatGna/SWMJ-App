using Microsoft.Data.SqlClient;
using WynajemApp.Models;

namespace WynajemApp.Data;

/// <summary>
/// Implementacja repozytorium laczaca sie z baza WynajemJednosladow w SQL Server.
/// Odczyty - bezposrednie SELECT-y. Akcje operacyjne - wywolania procedur z e08
/// (usp_Doladuj, usp_RozpocznijWypozyczenie, usp_ZakonczWypozyczenie). Triggery
/// z e08 sa egzekwowane przez baze - kazdy blad biznesowy (50001..50007) leci
/// do gory jako SqlException.
/// </summary>
public class SqlServerRepository : IDataRepository
{
    private readonly string _connStr;

    public SqlServerRepository(string connectionString)
    {
        _connStr = connectionString;
    }

    private SqlConnection Open()
    {
        var c = new SqlConnection(_connStr);
        c.Open();
        return c;
    }

    public IEnumerable<Uzytkownik> PobierzUzytkownikow()
    {
        const string sql = @"
            SELECT id_uzytkownika, imie, nazwisko, email, telefon, saldo
            FROM dbo.Uzytkownik
            ORDER BY id_uzytkownika;";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        using var r = cmd.ExecuteReader();
        var list = new List<Uzytkownik>();
        while (r.Read())
        {
            list.Add(new Uzytkownik
            {
                IdUzytkownika = r.GetInt32(0),
                Imie          = r.GetString(1),
                Nazwisko      = r.GetString(2),
                Email         = r.GetString(3),
                Telefon       = r.IsDBNull(4) ? string.Empty : r.GetString(4),
                Saldo         = r.GetDecimal(5)
            });
        }
        return list;
    }

    public IEnumerable<Pojazd> PobierzPojazdy()
    {
        const string sql = @"
            SELECT id_pojazdu, typ, numer_seryjny, status, stan_techniczny, id_stacji
            FROM dbo.Pojazd
            ORDER BY id_pojazdu;";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        using var r = cmd.ExecuteReader();
        var list = new List<Pojazd>();
        while (r.Read())
        {
            list.Add(new Pojazd
            {
                IdPojazdu      = r.GetInt32(0),
                Typ            = r.GetString(1),
                NumerSeryjny   = r.GetString(2),
                Status         = r.GetString(3),
                StanTechniczny = r.GetString(4),
                IdStacji       = r.IsDBNull(5) ? null : r.GetInt32(5)
            });
        }
        return list;
    }

    public IEnumerable<Stacja> PobierzStacje()
    {
        const string sql = @"
            SELECT id_stacji, nazwa, adres, pojemnosc
            FROM dbo.Stacja
            ORDER BY id_stacji;";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        using var r = cmd.ExecuteReader();
        var list = new List<Stacja>();
        while (r.Read())
        {
            list.Add(new Stacja
            {
                IdStacji  = r.GetInt32(0),
                Nazwa     = r.GetString(1),
                Adres     = r.GetString(2),
                Pojemnosc = r.GetInt32(3)
            });
        }
        return list;
    }

    public IEnumerable<Wypozyczenie> PobierzWypozyczenia()
    {
        const string sql = @"
            SELECT id_wypozyczenia, data_rozpoczecia, data_zakonczenia, oplata,
                   koncowa_szerokosc, koncowa_dlugosc,
                   id_uzytkownika, id_pojazdu, id_cennika,
                   id_stacji_startowej, id_stacji_koncowej
            FROM dbo.Wypozyczenie
            ORDER BY data_rozpoczecia DESC;";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        using var r = cmd.ExecuteReader();
        var list = new List<Wypozyczenie>();
        while (r.Read())
        {
            list.Add(new Wypozyczenie
            {
                IdWypozyczenia      = r.GetInt32(0),
                DataRozpoczecia     = r.GetDateTime(1),
                DataZakonczenia     = r.IsDBNull(2)  ? null : r.GetDateTime(2),
                Oplata              = r.IsDBNull(3)  ? null : r.GetDecimal(3),
                KoncowaSzerokosc    = r.IsDBNull(4)  ? null : Convert.ToDouble(r.GetValue(4)),
                KoncowaDlugosc      = r.IsDBNull(5)  ? null : Convert.ToDouble(r.GetValue(5)),
                IdUzytkownika       = r.GetInt32(6),
                IdPojazdu           = r.GetInt32(7),
                IdCennika           = r.GetInt32(8),
                IdStacjiStartowej   = r.GetInt32(9),
                IdStacjiKoncowej    = r.IsDBNull(10) ? null : r.GetInt32(10)
            });
        }
        return list;
    }

    public IEnumerable<Cennik> PobierzCennik()
    {
        const string sql = @"
            SELECT id_cennika, typ_pojazdu, stawka_za_minute, data_od, data_do
            FROM dbo.Cennik
            ORDER BY typ_pojazdu, data_od;";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        using var r = cmd.ExecuteReader();
        var list = new List<Cennik>();
        while (r.Read())
        {
            list.Add(new Cennik
            {
                IdCennika      = r.GetInt32(0),
                TypPojazdu     = r.GetString(1),
                StawkaZaMinute = r.GetDecimal(2),
                DataOd         = r.GetDateTime(3),
                DataDo         = r.IsDBNull(4) ? null : r.GetDateTime(4)
            });
        }
        return list;
    }

    public IEnumerable<Doladowanie> PobierzDoladowania()
    {
        const string sql = @"
            SELECT id_doladowania, kwota, data, id_uzytkownika
            FROM dbo.Doladowanie
            ORDER BY data DESC;";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        using var r = cmd.ExecuteReader();
        var list = new List<Doladowanie>();
        while (r.Read())
        {
            list.Add(new Doladowanie
            {
                IdDoladowania = r.GetInt32(0),
                Kwota         = r.GetDecimal(1),
                Data          = r.GetDateTime(2),
                IdUzytkownika = r.GetInt32(3)
            });
        }
        return list;
    }

    public void Doladuj(int idUzytkownika, decimal kwota)
    {
        using var conn = Open();
        using var cmd = new SqlCommand("dbo.usp_Doladuj", conn)
        {
            CommandType = System.Data.CommandType.StoredProcedure
        };
        cmd.Parameters.Add("@id_uzytkownika", System.Data.SqlDbType.Int).Value = idUzytkownika;
        cmd.Parameters.Add("@kwota", System.Data.SqlDbType.Decimal).Value = kwota;
        var outSaldo = cmd.Parameters.Add("@nowe_saldo", System.Data.SqlDbType.Decimal);
        outSaldo.Precision = 10;
        outSaldo.Scale = 2;
        outSaldo.Direction = System.Data.ParameterDirection.Output;
        cmd.ExecuteNonQuery();
    }

    public int RozpocznijWypozyczenie(int idUzytkownika, int idPojazdu, int idCennika, int idStacjiStartowej)
    {
        using var conn = Open();
        using var cmd = new SqlCommand("dbo.usp_RozpocznijWypozyczenie", conn)
        {
            CommandType = System.Data.CommandType.StoredProcedure
        };
        cmd.Parameters.Add("@id_uzytkownika", System.Data.SqlDbType.Int).Value = idUzytkownika;
        cmd.Parameters.Add("@id_pojazdu", System.Data.SqlDbType.Int).Value = idPojazdu;
        cmd.Parameters.Add("@id_cennika", System.Data.SqlDbType.Int).Value = idCennika;
        cmd.Parameters.Add("@id_stacji_startowej", System.Data.SqlDbType.Int).Value = idStacjiStartowej;
        var outId = cmd.Parameters.Add("@id_wypozyczenia", System.Data.SqlDbType.Int);
        outId.Direction = System.Data.ParameterDirection.Output;
        cmd.ExecuteNonQuery();
        return (int)outId.Value;
    }

    public void ZakonczWypozyczenie(int idWypozyczenia, int? idStacjiKoncowej, double? lat, double? lng)
    {
        using var conn = Open();
        using var cmd = new SqlCommand("dbo.usp_ZakonczWypozyczenie", conn)
        {
            CommandType = System.Data.CommandType.StoredProcedure
        };
        cmd.Parameters.Add("@id_wypozyczenia", System.Data.SqlDbType.Int).Value = idWypozyczenia;
        cmd.Parameters.Add("@id_stacji_koncowej", System.Data.SqlDbType.Int).Value
            = (object?)idStacjiKoncowej ?? DBNull.Value;

        var pLat = cmd.Parameters.Add("@koncowa_szerokosc", System.Data.SqlDbType.Decimal);
        pLat.Precision = 9; pLat.Scale = 6;
        pLat.Value = lat.HasValue ? (decimal)lat.Value : DBNull.Value;

        var pLng = cmd.Parameters.Add("@koncowa_dlugosc", System.Data.SqlDbType.Decimal);
        pLng.Precision = 9; pLng.Scale = 6;
        pLng.Value = lng.HasValue ? (decimal)lng.Value : DBNull.Value;

        var outOplata = cmd.Parameters.Add("@oplata", System.Data.SqlDbType.Decimal);
        outOplata.Precision = 10; outOplata.Scale = 2;
        outOplata.Direction = System.Data.ParameterDirection.Output;

        cmd.ExecuteNonQuery();
    }

    // -----------------------------------------------------------------
    // CRUD na tabelach (INSERT/UPDATE/DELETE). Walidacje (triggery z e08)
    // egzekwowane przez baze, leca jako SqlException.
    // -----------------------------------------------------------------

    public int DodajUzytkownika(string imie, string nazwisko, string email, string telefon)
    {
        const string sql = @"
            INSERT INTO dbo.Uzytkownik (imie, nazwisko, email, telefon, saldo)
            OUTPUT INSERTED.id_uzytkownika
            VALUES (@imie, @nazwisko, @email, @telefon, 0);";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add("@imie",     System.Data.SqlDbType.NVarChar, 50).Value  = imie;
        cmd.Parameters.Add("@nazwisko", System.Data.SqlDbType.NVarChar, 50).Value  = nazwisko;
        cmd.Parameters.Add("@email",    System.Data.SqlDbType.NVarChar, 100).Value = email;
        cmd.Parameters.Add("@telefon",  System.Data.SqlDbType.NVarChar, 20).Value
            = string.IsNullOrWhiteSpace(telefon) ? DBNull.Value : telefon;
        return (int)cmd.ExecuteScalar();
    }

    public void EdytujUzytkownika(int id, string imie, string nazwisko, string email, string telefon)
    {
        const string sql = @"
            UPDATE dbo.Uzytkownik
               SET imie = @imie, nazwisko = @nazwisko, email = @email, telefon = @telefon
             WHERE id_uzytkownika = @id;";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add("@id",       System.Data.SqlDbType.Int).Value = id;
        cmd.Parameters.Add("@imie",     System.Data.SqlDbType.NVarChar, 50).Value  = imie;
        cmd.Parameters.Add("@nazwisko", System.Data.SqlDbType.NVarChar, 50).Value  = nazwisko;
        cmd.Parameters.Add("@email",    System.Data.SqlDbType.NVarChar, 100).Value = email;
        cmd.Parameters.Add("@telefon",  System.Data.SqlDbType.NVarChar, 20).Value
            = string.IsNullOrWhiteSpace(telefon) ? DBNull.Value : telefon;
        cmd.ExecuteNonQuery();
    }

    public void UsunUzytkownika(int id)
    {
        const string sql = @"DELETE FROM dbo.Uzytkownik WHERE id_uzytkownika = @id;";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add("@id", System.Data.SqlDbType.Int).Value = id;
        cmd.ExecuteNonQuery();
    }

    public int DodajPojazd(string typ, string numerSeryjny, string status, string stanTechniczny, int? idStacji)
    {
        const string sql = @"
            INSERT INTO dbo.Pojazd (typ, numer_seryjny, status, stan_techniczny, id_stacji)
            OUTPUT INSERTED.id_pojazdu
            VALUES (@typ, @nr, @status, @stan, @idStacji);";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add("@typ",      System.Data.SqlDbType.NVarChar, 20).Value = typ;
        cmd.Parameters.Add("@nr",       System.Data.SqlDbType.NVarChar, 30).Value = numerSeryjny;
        cmd.Parameters.Add("@status",   System.Data.SqlDbType.NVarChar, 20).Value = status;
        cmd.Parameters.Add("@stan",     System.Data.SqlDbType.NVarChar, 20).Value = stanTechniczny;
        cmd.Parameters.Add("@idStacji", System.Data.SqlDbType.Int).Value
            = (object?)idStacji ?? DBNull.Value;
        return (int)cmd.ExecuteScalar();
    }

    public void ZmienStatusPojazdu(int idPojazdu, string status, int? idStacji)
    {
        const string sql = @"
            UPDATE dbo.Pojazd
               SET status = @status, id_stacji = @idStacji
             WHERE id_pojazdu = @id;";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add("@id",       System.Data.SqlDbType.Int).Value = idPojazdu;
        cmd.Parameters.Add("@status",   System.Data.SqlDbType.NVarChar, 20).Value = status;
        cmd.Parameters.Add("@idStacji", System.Data.SqlDbType.Int).Value
            = (object?)idStacji ?? DBNull.Value;
        cmd.ExecuteNonQuery();
    }

    public int DodajStacje(string nazwa, string adres, int pojemnosc)
    {
        const string sql = @"
            INSERT INTO dbo.Stacja (nazwa, adres, pojemnosc)
            OUTPUT INSERTED.id_stacji
            VALUES (@nazwa, @adres, @poj);";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add("@nazwa", System.Data.SqlDbType.NVarChar, 100).Value = nazwa;
        cmd.Parameters.Add("@adres", System.Data.SqlDbType.NVarChar, 200).Value = adres;
        cmd.Parameters.Add("@poj",   System.Data.SqlDbType.Int).Value = pojemnosc;
        return (int)cmd.ExecuteScalar();
    }

    public int DodajCennik(string typPojazdu, decimal stawkaZaMinute, DateTime dataOd, DateTime? dataDo)
    {
        const string sql = @"
            INSERT INTO dbo.Cennik (typ_pojazdu, stawka_za_minute, data_od, data_do)
            OUTPUT INSERTED.id_cennika
            VALUES (@typ, @stawka, @od, @do);";
        using var conn = Open();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add("@typ",    System.Data.SqlDbType.NVarChar, 20).Value = typPojazdu;
        cmd.Parameters.Add("@stawka", System.Data.SqlDbType.Decimal).Value = stawkaZaMinute;
        cmd.Parameters.Add("@od",     System.Data.SqlDbType.Date).Value = dataOd.Date;
        cmd.Parameters.Add("@do",     System.Data.SqlDbType.Date).Value
            = dataDo.HasValue ? dataDo.Value.Date : (object)DBNull.Value;
        return (int)cmd.ExecuteScalar();
    }
}

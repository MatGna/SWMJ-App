using WynajemApp.Data;

namespace WynajemApp;

/// <summary>
/// Prosty kontener na zaleznosci. W jednym miejscu trzymamy aktualne repozytorium,
/// dzieki czemu pozniej wystarczy podmienic linijke aby przeskoczyc na SQL Server.
/// </summary>
public static class AppServices
{
    // Pozniej zamiana na: new SqlServerRepository(connectionString)
    public static IDataRepository Repository { get; } = new MockDataRepository();
}

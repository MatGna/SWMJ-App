using Microsoft.Extensions.Configuration;
using WynajemApp.Data;

namespace WynajemApp;

/// <summary>
/// Prosty kontener na zaleznosci. Repozytorium budowane raz na starcie
/// na podstawie appsettings.json. Default = SqlServerRepository; fallback na
/// Mock gdy w konfiguracji UseMockRepository=true (lub gdy brak connection
/// stringu).
/// </summary>
public static class AppServices
{
    public static IDataRepository Repository { get; private set; } = new MockDataRepository();
    public static string ZrodloDanych { get; private set; } = "MockDataRepository (default - przed wczytaniem konfiguracji)";

    public static void Init(IConfiguration config)
    {
        var useMock = config.GetValue<bool>("UseMockRepository");
        var connStr = config.GetConnectionString("WynajemDb");

        if (useMock || string.IsNullOrWhiteSpace(connStr))
        {
            Repository = new MockDataRepository();
            ZrodloDanych = "MockDataRepository (dane w pamieci)";
            return;
        }

        Repository = new SqlServerRepository(connStr!);
        ZrodloDanych = "SqlServerRepository (WynajemJednosladow)";
    }
}

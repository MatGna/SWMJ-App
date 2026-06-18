# Wynajem Jednosladow - uruchomienie

## Wymagania

- **Docker Desktop** (z `docker compose`)
- **.NET 8 SDK** ([download](https://dotnet.microsoft.com/download/dotnet/8.0))
- Windows (aplikacja to WPF)

## 1. Konfiguracja (jednorazowo)

W folderze projektu skopiuj dwa pliki przykladowe i wstaw to samo haslo SA w obu:

```powershell
Copy-Item .env.example .env
Copy-Item WynajemApp\appsettings.example.json WynajemApp\appsettings.json
```

Otworz oba i ustaw silne haslo:

- `.env` -> `MSSQL_SA_PASSWORD=TwojeHaslo123!`
- `WynajemApp\appsettings.json` -> w `ConnectionStrings.WynajemDb` zmien `Password=...` na to samo

> Haslo musi miec min. 8 znakow, w tym wielka litera, mala, cyfra i znak specjalny (wymog MSSQL).

## 2. Uruchomienie

```powershell
docker compose up -d                                     # start bazy + seed (pierwszy raz)
dotnet run --project WynajemApp\WynajemApp.csproj        # uruchom aplikacje
```

Pierwszy `up` trwa ~30s (ciagniecie obrazu MSSQL + seed danych z `db/init/`).  
Sprawdzenie ze baza siadla:

```powershell
docker compose ps        # sql -> 'healthy', init -> exited (0)
```

## 3. Zatrzymanie / reset

```powershell
docker compose down       # zatrzymaj (dane zostaja w wolumenie)
docker compose down -v    # zatrzymaj + skasuj dane (nastepny up zrobi swiezy seed)
```

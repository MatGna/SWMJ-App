#!/bin/bash
set -e

# Czekam az SQL Server bedzie gotowy (proba polaczenia co 2s, max 60s).
SQLCMD="/opt/mssql-tools18/bin/sqlcmd -S sql -U sa -P $MSSQL_SA_PASSWORD -C -No -I"

echo "Init: czekam na SQL Server..."
for i in {1..30}; do
    if $SQLCMD -Q "SELECT 1" -h -1 > /dev/null 2>&1; then
        echo "Init: SQL Server odpowiada."
        break
    fi
    sleep 2
done

if ! $SQLCMD -Q "SELECT 1" -h -1 > /dev/null 2>&1; then
    echo "Init: SQL Server nie wystartowal w 60s - przerywam."
    exit 1
fi

# Sprawdzam czy baza juz istnieje + ma tabele Uzytkownik (marker pelnego seedu).
# Jesli tak - pomijam init, dane uzytkownika sa zachowane miedzy restartami.
EXISTS=$($SQLCMD -d master -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases d INNER JOIN sys.tables t ON t.object_id = OBJECT_ID('WynajemJednosladow.dbo.Uzytkownik') WHERE d.name='WynajemJednosladow';" -h -1 2>/dev/null | tr -d '[:space:]' || echo "0")

if [ "$EXISTS" = "1" ]; then
    echo "Init: baza WynajemJednosladow juz istnieje ze schematem - pomijam seed."
    echo "Init: zeby wymusic reseed, uzyj 'docker compose down -v' i 'docker compose up'."
    exit 0
fi

echo "Init: pierwszy start - laduje skrypty 01..04..."

for f in /db-init/01_e06_schemat.sql /db-init/02_e08_logika.sql /db-init/03_e09_raporty.sql /db-init/04_e10_dane.sql; do
    echo "Init: -> $f"
    $SQLCMD -d master -i "$f" -b
done

echo "Init: uruchamiam testy weryfikacyjne (usp_TestyWszystkie)..."
$SQLCMD -d WynajemJednosladow -Q "EXEC dbo.usp_TestyWszystkie;" -W -s "|"

echo "Init: gotowe. Baza WynajemJednosladow zaladowana."

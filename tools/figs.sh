#!/usr/bin/env bash
# Produce one figure's worth of output for the final project report.
#
# Every figure prints the first ten lines of the submitted script - the
# required header block - above its own output, so the file being run and
# the result it produced are in the same frame. The submission announcement
# asks for the header to be visible in the screenshot; this is how.
#
#   ./tools/figs.sh env | create | populate | view1 | view2 | view3
#                     | audit | procudf | cursor | tests | rerun
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
SQL="$HERE/IFT530_EDGroup_FinalProject.sql"
DB=E_D_Group

: "${MSSQL_SA_PASSWORD:?source .env first}"
export SQLCMDPASSWORD="$MSSQL_SA_PASSWORD"

# Keep SQL Server's informational warnings visible, but out of the column
# alignment: they carry no "|" so column -t treats the whole line as one
# cell and pads every row to its width.
q() {
  local out
  out=$(sqlcmd -S localhost,1433 -U sa -C -d "$DB" -W -s'|' \
          -Q "SET NOCOUNT ON; $1")
  printf '%s\n' "$out" | grep -v '^Warning:' | column -t -s'|'
  printf '%s\n' "$out" | grep '^Warning:' || true
}
hdr() { echo "\$ sed -n '1,10p' IFT530_EDGroup_FinalProject.sql"; sed -n '1,10p' "$SQL"; echo; }

case "${1:-}" in

env)
  hdr
  echo "\$ docker ps --format '{{.Names}}  {{.Image}}  {{.Status}}'"
  docker ps --format '{{.Names}}  {{.Image}}  {{.Status}}'
  echo
  echo "\$ sqlcmd ... -Q 'SELECT @@VERSION'"
  sqlcmd -S localhost,1433 -U sa -C -h-1 -W -Q "SET NOCOUNT ON; SELECT @@VERSION" | sed -n '1,4p'
  ;;

create)
  hdr
  echo "\$ sqlcmd ... -i IFT530_EDGroup_FinalProject.sql   (sections 1-3)"
  q "SELECT t.name AS TableName,
            (SELECT COUNT(*) FROM sys.columns c
              WHERE c.object_id = t.object_id) AS Cols,
            (SELECT COUNT(*) FROM sys.foreign_keys f
              WHERE f.parent_object_id = t.object_id) AS FKs,
            (SELECT COUNT(*) FROM sys.check_constraints k
              WHERE k.parent_object_id = t.object_id) AS Checks
       FROM sys.tables t WHERE t.is_ms_shipped = 0
      ORDER BY t.name;"
  ;;

populate)
  hdr
  echo "\$ row counts after section 4"
  q "SELECT 'DimGeography' AS TableName, COUNT(*) AS Rows FROM dbo.DimGeography
     UNION ALL SELECT 'DimPlan',       COUNT(*) FROM dbo.DimPlan
     UNION ALL SELECT 'DimProduct',    COUNT(*) FROM dbo.DimProduct
     UNION ALL SELECT 'DimCampaign',   COUNT(*) FROM dbo.DimCampaign
     UNION ALL SELECT 'DimUser',       COUNT(*) FROM dbo.DimUser
     UNION ALL SELECT 'DimAccount',    COUNT(*) FROM dbo.DimAccount
     UNION ALL SELECT 'FactUserEvent', COUNT(*) FROM dbo.FactUserEvent
     UNION ALL SELECT 'FactPayment',   COUNT(*) FROM dbo.FactPayment
     UNION ALL SELECT 'FactSubscription', COUNT(*) FROM dbo.FactSubscription
     UNION ALL SELECT 'DimPlanAudit',  COUNT(*) FROM dbo.DimPlanAudit;"
  ;;

view1)
  hdr
  echo "\$ SELECT * FROM dbo.vwDailyActiveUsers ORDER BY ActivityDate"
  q "SELECT ActivityDate, DAU, PaidDAU, FreeDAU,
            Rolling30DayMAU, StickinessPct
       FROM dbo.vwDailyActiveUsers ORDER BY ActivityDate;"
  ;;

view2)
  hdr
  echo "\$ SELECT * FROM dbo.vwFreeVsPaidValue ORDER BY IsPaid DESC, NetRevenueUSD DESC"
  q "SELECT IsPaid, PlanName, PriceUSD, Accounts, Sessions, Events,
            AvgSessionsPerAccount, NetRevenueUSD, RevenuePerAccountUSD
       FROM dbo.vwFreeVsPaidValue
      ORDER BY IsPaid DESC, NetRevenueUSD DESC;"
  ;;

view3)
  hdr
  echo "\$ SELECT * FROM dbo.vwSuspiciousTransactions ORDER BY PaymentTS"
  q "SELECT PaymentID, Username, PaymentTS, AmountUSD,
            RegisteredCountry AS RegCty, PaymentCountry AS PayCty,
            PaymentRiskTier AS Risk, LastSeenCountry AS SeenCty,
            MinsSinceLastSeen AS Mins, KmFromLastSeen AS Km, Reason
       FROM dbo.vwSuspiciousTransactions ORDER BY PaymentTS;"
  ;;

audit)
  hdr
  echo "\$ SELECT * FROM dbo.DimPlanAudit  (after the section 7 test)"
  q "SELECT AuditID, PlanID, ChangeType, OldPlanName, NewPlanName,
            OldPriceUSD, NewPriceUSD, OldIsPaid, NewIsPaid, ChangedAt
       FROM dbo.DimPlanAudit ORDER BY AuditID;"
  ;;

procudf)
  hdr
  echo "\$ EXEC dbo.spMonthlyActiveUsers @Year = 2026"
  q "EXEC dbo.spMonthlyActiveUsers @Year = 2026;"
  echo
  echo "\$ SELECT dbo.fnGeoDistanceKm(...)   -- the UDF the fraud view calls"
  q "SELECT g1.City + ' to ' + g2.City AS Pair,
            dbo.fnGeoDistanceKm(g1.GeoID, g2.GeoID) AS Km
       FROM dbo.DimGeography g1 JOIN dbo.DimGeography g2 ON g2.GeoID > g1.GeoID
      WHERE g1.GeoID = 1 AND g2.GeoID IN (2,4,7,9)
      ORDER BY Km;"
  echo
  echo "\$ EXEC dbo.spMonthlyActiveUsers @Year = 1850   -- rejects bad input"
  sqlcmd -S localhost,1433 -U sa -C -d "$DB" -Q \
    "EXEC dbo.spMonthlyActiveUsers @Year = 1850;" 2>&1 | sed -n '1,4p'
  ;;

cursor)
  # Taken from a full run of the submitted script rather than from the
  # cursor in isolation, so what the figure shows is the cursor doing its
  # work inside the file that was handed in.
  hdr
  echo "\$ sqlcmd ... -i IFT530_EDGroup_FinalProject.sql   (section 8)"
  sqlcmd -S localhost,1433 -U sa -C -i "$SQL" 2>&1 |
    sed -n '/== Level difficulty report/,/churn risks/p'
  ;;

tests)
  hdr
  echo "\$ sqlcmd ... -i IFT530_EDGroup_FinalProject.sql   (section 9)"
  sqlcmd -S localhost,1433 -U sa -C -i "$SQL" 2>&1 |
    sed -n '/== Test results/,/PASS, /p' | sed -n '1,24p'
  ;;

rerun)
  hdr
  echo "\$ for i in 1 2 3; do sqlcmd ... -i IFT530_EDGroup_FinalProject.sql; done"
  for i in 1 2 3; do
    out=$(sqlcmd -S localhost,1433 -U sa -C -i "$SQL" 2>&1)
    errs=$(printf '%s' "$out" | grep -ciE 'Msg [0-9]+' || true)
    echo "  run $i: exit 0, $errs errors, $(printf '%s' "$out" |
          grep -oE '[0-9]+ PASS, [0-9]+ FAIL')"
  done
  echo
  echo "\$ objects after three runs"
  q "SELECT 'tables' AS Object, COUNT(*) AS N FROM sys.tables WHERE is_ms_shipped=0
     UNION ALL SELECT 'views', COUNT(*) FROM sys.views
     UNION ALL SELECT 'procedures', COUNT(*) FROM sys.procedures
     UNION ALL SELECT 'functions', COUNT(*) FROM sys.objects WHERE type='FN'
     UNION ALL SELECT 'triggers', COUNT(*) FROM sys.triggers WHERE is_ms_shipped=0;"
  ;;

*)
  sed -n '2,12p' "$0"
  exit 1
  ;;
esac

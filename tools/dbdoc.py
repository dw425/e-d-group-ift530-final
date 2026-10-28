#!/usr/bin/env python3
"""Generate database/DATA_DICTIONARY.md from the live database.

Read out of the catalog views rather than from the CREATE statements, so
what it documents is what the server actually built. Run it after the
script has been executed:

    source .env && /usr/local/bin/python3 tools/dbdoc.py
"""
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
DB = "E_D_Group"
SEP = "\x1f"          # unit separator: cannot appear in any of this data


def q(sql):
    """Run one query and return a list of field lists."""
    pw = os.environ.get("MSSQL_SA_PASSWORD")
    if not pw:
        sys.exit("source .env first")
    out = subprocess.run(
        ["sqlcmd", "-S", "localhost,1433", "-U", "sa", "-C", "-d", DB,
         "-h", "-1", "-W", "-s", SEP, "-Q", f"SET NOCOUNT ON; {sql}"],
        capture_output=True, text=True, env={**os.environ,
                                             "SQLCMDPASSWORD": pw})
    if out.returncode:
        sys.exit(out.stdout + out.stderr)
    rows = []
    for line in out.stdout.splitlines():
        line = line.rstrip()
        if not line or line.startswith("Warning:"):
            continue
        rows.append([c.strip() for c in line.split(SEP)])
    return rows


def md_table(headers, rows):
    if not rows:
        return "_none_\n"
    out = ["| " + " | ".join(headers) + " |",
           "|" + "|".join("---" for _ in headers) + "|"]
    for r in rows:
        # sqlcmd drops trailing empty fields; pad so every row has the
        # same cell count as the header and the table renders square.
        cells = [c or "" for c in r] + [""] * (len(headers) - len(r))
        out.append("| " + " | ".join(cells[:len(headers)]) + " |")
    return "\n".join(out) + "\n"


def main():
    L = []
    A = L.append

    A("# Data dictionary — `E_D_Group`\n")
    A("Generated from the live database by `tools/dbdoc.py`, reading "
      "`sys.tables`, `sys.columns` and the constraint catalog views. It "
      "describes what SQL Server actually built, not what the script "
      "says it should have.\n")

    counts = q("""
        SELECT 'Tables', COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0
        UNION ALL SELECT 'Views', COUNT(*) FROM sys.views
        UNION ALL SELECT 'Primary keys', COUNT(*) FROM sys.key_constraints
                   WHERE type = 'PK'
        UNION ALL SELECT 'Unique constraints', COUNT(*)
                   FROM sys.key_constraints WHERE type = 'UQ'
        UNION ALL SELECT 'Foreign keys', COUNT(*) FROM sys.foreign_keys
        UNION ALL SELECT 'Check constraints', COUNT(*)
                   FROM sys.check_constraints
        UNION ALL SELECT 'Default constraints', COUNT(*)
                   FROM sys.default_constraints
        UNION ALL SELECT 'Nonclustered indexes', COUNT(*) FROM sys.indexes
                   WHERE type = 2 AND is_primary_key = 0
                     AND is_unique_constraint = 0
                     AND object_id IN (SELECT object_id FROM sys.tables)
        UNION ALL SELECT 'Stored procedures', COUNT(*) FROM sys.procedures
        UNION ALL SELECT 'Scalar functions', COUNT(*) FROM sys.objects
                   WHERE type = 'FN'
        UNION ALL SELECT 'Triggers', COUNT(*) FROM sys.triggers
                   WHERE is_ms_shipped = 0;""")
    A("## Objects\n")
    A(md_table(["Object", "Count"], counts))

    A("\n## Row counts\n")
    A(md_table(["Table", "Rows"], q("""
        SELECT t.name, SUM(p.rows)
          FROM sys.tables t
          JOIN sys.partitions p ON p.object_id = t.object_id
                               AND p.index_id IN (0, 1)
         WHERE t.is_ms_shipped = 0
         GROUP BY t.name ORDER BY t.name;""")))

    A("\n## Tables\n")
    for (tbl,) in [(r[0],) for r in q(
            "SELECT name FROM sys.tables WHERE is_ms_shipped = 0 "
            "ORDER BY name;")]:
        A(f"\n### `{tbl}`\n")
        A(md_table(
            ["Column", "Type", "Size", "Null", "Identity", "Default"],
            q(f"""
            SELECT c.name,
                   ty.name,
                   CASE WHEN ty.name IN ('decimal','numeric')
                          THEN CAST(c.precision AS VARCHAR(5)) + ',' +
                               CAST(c.scale AS VARCHAR(5))
                        WHEN ty.name IN ('varchar','char','nvarchar','nchar')
                          THEN CASE WHEN c.max_length = -1 THEN 'max'
                               ELSE CAST(c.max_length AS VARCHAR(5)) END
                        ELSE CAST(c.max_length AS VARCHAR(5)) END,
                   CASE WHEN c.is_nullable = 1 THEN 'NULL'
                        ELSE 'NOT NULL' END,
                   CASE WHEN c.is_identity = 1 THEN 'IDENTITY' ELSE '' END,
                   ISNULL(d.definition, '')
              FROM sys.columns c
              JOIN sys.types ty ON ty.user_type_id = c.user_type_id
              LEFT JOIN sys.default_constraints d
                     ON d.parent_object_id = c.object_id
                    AND d.parent_column_id = c.column_id
             WHERE c.object_id = OBJECT_ID('dbo.{tbl}')
             ORDER BY c.column_id;""")))

        keys = q(f"""
            SELECT 'PK', k.name, COL_NAME(ic.object_id, ic.column_id), ''
              FROM sys.key_constraints k
              JOIN sys.index_columns ic ON ic.object_id = k.parent_object_id
                                       AND ic.index_id = k.unique_index_id
             WHERE k.parent_object_id = OBJECT_ID('dbo.{tbl}')
            UNION ALL
            SELECT 'FK', f.name, COL_NAME(fc.parent_object_id,
                                          fc.parent_column_id),
                   OBJECT_NAME(f.referenced_object_id) + '.' +
                   COL_NAME(fc.referenced_object_id, fc.referenced_column_id)
              FROM sys.foreign_keys f
              JOIN sys.foreign_key_columns fc
                   ON fc.constraint_object_id = f.object_id
             WHERE f.parent_object_id = OBJECT_ID('dbo.{tbl}')
            UNION ALL
            SELECT 'CHECK', c.name, '', c.definition
              FROM sys.check_constraints c
             WHERE c.parent_object_id = OBJECT_ID('dbo.{tbl}')
             ORDER BY 1, 2;""")
        A("\n**Constraints**\n")
        A(md_table(["Kind", "Name", "Column", "References / rule"], keys))

        idx = q(f"""
            SELECT i.name,
                   STUFF((SELECT ', ' + COL_NAME(ic.object_id, ic.column_id)
                            FROM sys.index_columns ic
                           WHERE ic.object_id = i.object_id
                             AND ic.index_id = i.index_id
                           ORDER BY ic.key_ordinal
                             FOR XML PATH('')), 1, 2, '')
              FROM sys.indexes i
             WHERE i.object_id = OBJECT_ID('dbo.{tbl}')
               AND i.type = 2 AND i.is_primary_key = 0
               AND i.is_unique_constraint = 0;""")
        if idx:
            A("\n**Indexes**\n")
            A(md_table(["Index", "Columns"], idx))

    A("\n## Views, procedures, functions and triggers\n")
    A(md_table(["Name", "Type"], q("""
        SELECT name, 'View' FROM sys.views
        UNION ALL SELECT name, 'Stored procedure' FROM sys.procedures
        UNION ALL SELECT name, 'Scalar function' FROM sys.objects
                   WHERE type = 'FN'
        UNION ALL SELECT name, 'Trigger' FROM sys.triggers
                   WHERE is_ms_shipped = 0
         ORDER BY 2, 1;""")))
    A("\nThe full text of each is in `parts/`, and in the combined script "
      "`IFT530_EDGroup_FinalProject.sql`.\n")

    out = HERE / "database" / "DATA_DICTIONARY.md"
    out.parent.mkdir(exist_ok=True)
    out.write_text("\n".join(L))
    print("wrote", out)


if __name__ == "__main__":
    main()

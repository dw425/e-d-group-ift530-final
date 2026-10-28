# The built database

This folder is the database itself, not just the script that makes it.

| File | What it is |
|---|---|
| `E_D_Group.bak` | A full SQL Server backup of the built and populated database. |
| `DATA_DICTIONARY.md` | Every table, column, constraint and index, read out of the live catalog by `tools/dbdoc.py`. |

## Restoring the backup

The backup was taken from SQL Server 2025 on Linux, so restore it to 2025
or later. Earlier versions will refuse it — in that case run the script
instead, which builds the same database from scratch.

**In Docker** (what this was made on), copy the file in and restore it:

    docker cp E_D_Group.bak <container>:/var/opt/mssql/backup/

    sqlcmd -S localhost,1433 -U sa -C -Q "
      RESTORE DATABASE E_D_Group
        FROM DISK = '/var/opt/mssql/backup/E_D_Group.bak'
        WITH MOVE 'E_D_Group'     TO '/var/opt/mssql/data/E_D_Group.mdf',
             MOVE 'E_D_Group_log' TO '/var/opt/mssql/data/E_D_Group_log.ldf',
             REPLACE;"

**On Windows**, the two `MOVE` targets become ordinary paths such as
`C:\SQLData\E_D_Group.mdf`. To see the logical names the backup carries:

    RESTORE FILELISTONLY FROM DISK = 'E_D_Group.bak';

## Or build it from the script

The backup is a convenience, not the deliverable. The script is:

    sqlcmd -S localhost,1433 -U sa -C -i ../IFT530_EDGroup_FinalProject.sql

It creates the database, drops and rebuilds every object inside it, loads
the data, and finishes with thirteen tests. It is safe to run repeatedly —
it has been run three times in a row, clean each time.

## What is in it

Ten tables, three views, one stored procedure, one scalar function and one
trigger. Ten rows in every dimension; 48, 30 and 23 in the three fact
tables, which is the load the assignment asks for. `DimPlanAudit` holds
three rows, written by the trigger when the audit test ran — it starts
empty, because that is the point of it.

## Regenerating the dictionary

    source .env && /usr/local/bin/python3 tools/dbdoc.py

It reads `sys.tables`, `sys.columns` and the constraint catalog views, so
it documents what the server actually built rather than what the script
claims.

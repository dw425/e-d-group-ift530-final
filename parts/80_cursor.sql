/*
** Author: Ethan Oxley, Daniel Warren
** Group: E & D Group
** Course: IFT 530: Advanced Database Management Systems
** SQL Server Version: Microsoft SQL Server 2025 (Developer Edition)
** OS: macOS 26.5.1 (SQL Server running in Microsoft's official Linux
**     container under Docker)
** Date: 10/27/2026
** Assignment: Final Project
*/

/* ======================================================================
   SECTION 8: A CURSOR

   What it does: walks the ten levels in play order and prints a
   difficulty line for each one, comparing the difficulty the designers
   assigned against the failure rate the event data actually shows, and
   flagging any level players lose more often than they win.

   Why a cursor is defensible here, when set-based SQL is almost always
   the right answer: the output is a printed report, one PRINT per level
   with running commentary, and PRINT is not something a set-based
   statement can do per row. A result set would be the better choice for
   anything a program consumes; this is for a person reading a log.

   On "create and drop script for cursor": a cursor has no CREATE or
   DROP in T-SQL. It is DECLARE ... CURSOR and DEALLOCATE. Declaring it
   GLOBAL makes those two genuinely separate statements against a named
   object that outlives its batch, which is as close to create and drop
   as a cursor gets, and it means the DEALLOCATE below is a real drop
   rather than a formality.
   ====================================================================== */

/* If a previous run failed between OPEN and DEALLOCATE the name is
   still taken, and DECLARE would fail with "a cursor with the name
   already exists". This clears it first, which is what keeps section 8
   re-runnable. */
IF CURSOR_STATUS('global', 'curLevelDifficulty') >= -1
BEGIN
    CLOSE curLevelDifficulty;
    DEALLOCATE curLevelDifficulty;
END;
GO

/* ---- create the cursor -------------------------------------------- */
DECLARE curLevelDifficulty CURSOR GLOBAL
FOR
    SELECT  e.LevelNumber,
            COUNT(*) AS Attempts,
            SUM(CASE WHEN e.Outcome = 'Win'  THEN 1 ELSE 0 END) AS Wins,
            SUM(CASE WHEN e.Outcome = 'Loss' THEN 1 ELSE 0 END) AS Losses,
            SUM(CASE WHEN e.Outcome = 'Abandon'
                     THEN 1 ELSE 0 END) AS Abandons
      FROM  dbo.FactUserEvent AS e
     WHERE  e.LevelNumber IS NOT NULL
       AND  e.Outcome     IS NOT NULL
     GROUP BY e.LevelNumber
     ORDER BY e.LevelNumber;

OPEN curLevelDifficulty;

DECLARE @Level    INT,
        @Attempts INT,
        @Wins     INT,
        @Losses   INT,
        @Abandons INT,
        @WinPct   DECIMAL(5,2),
        @Line     VARCHAR(200),
        @Flagged  INT = 0;

PRINT '== Level difficulty report';
PRINT 'Level  Attempts   Wins  Losses  Aband   Win%  Verdict';
PRINT '-----  --------  -----  ------  -----  -----  -------';

FETCH NEXT FROM curLevelDifficulty
 INTO @Level, @Attempts, @Wins, @Losses, @Abandons;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @WinPct = CAST(100.0 * @Wins / NULLIF(@Attempts, 0)
                       AS DECIMAL(5,2));

    SET @Line =
        RIGHT(SPACE(12) + CAST(@Level    AS VARCHAR(12)),  5) +
        RIGHT(SPACE(12) + CAST(@Attempts AS VARCHAR(12)), 10) +
        RIGHT(SPACE(12) + CAST(@Wins     AS VARCHAR(12)),  7) +
        RIGHT(SPACE(12) + CAST(@Losses   AS VARCHAR(12)),  8) +
        RIGHT(SPACE(12) + CAST(@Abandons AS VARCHAR(12)),  7) +
        RIGHT(SPACE(12) + CAST(@WinPct   AS VARCHAR(12)),  7) +
        '  ' +
        CASE WHEN @WinPct < 50.0 THEN 'CHURN RISK - lost more than won'
             WHEN @WinPct < 60.0 THEN 'hard'
             ELSE                     'ok' END;

    PRINT @Line;

    IF @WinPct < 50.0
        SET @Flagged = @Flagged + 1;

    FETCH NEXT FROM curLevelDifficulty
     INTO @Level, @Attempts, @Wins, @Losses, @Abandons;
END;

PRINT '-----  --------  -----  ------  -----  -----  -------';
PRINT 'Levels flagged as churn risks: ' + CAST(@Flagged AS VARCHAR(5));

/* ---- drop the cursor ----------------------------------------------- */
CLOSE curLevelDifficulty;
DEALLOCATE curLevelDifficulty;
GO

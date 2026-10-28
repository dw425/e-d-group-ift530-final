/*
** Author: Ethan Oxley, Daniel Warren
** Group: E & D Group
** Course: IFT 530: Advanced Database Management Systems
** SQL Server Version: Microsoft SQL Server 2025 (Developer Edition)
** OS: macOS 26.6.2 (SQL Server running in Microsoft's official Linux
**     container under Docker)
** Date: 10/27/2026
** Assignment: Final Project
*/

/* ======================================================================
   IFT 530: Advanced Database Management Systems
   Final Project - E & D Group
   Ethan Oxley, Daniel Warren

   A player analytics database for a live, free-to-play online game.
   Ten tables: six dimensions describing the customer from different
   angles, three fact tables recording what happened, and one audit
   table holding the change history of the plan lookup.

   The design question behind it is that this kind of game earns nothing
   when somebody installs it. It earns weeks later, from a fraction of
   players who decide it is worth paying for, and it only reaches those
   players by buying their attention first. So the useful questions span
   areas usually kept apart: who the customer is, what they did, what
   they pay, and whether the payment should be trusted.

   Sections, in the order they run:

     1. Create the database
     2. Drop every object this script creates
     3. Create the ten tables and their indexes
     4. Populate them
     5. A user defined function and a stored procedure
     6. Three queries, each also saved as a view
     7. The audit table's trigger, with an insert/update/delete test
     8. A cursor
     9. Tests

   The function comes before the views because the suspicious
   transaction view in section 6 calls it.

   Re-runnable. Section 2 drops every view, procedure, function, trigger
   and table before section 3 creates them, so a second run replaces the
   database rather than failing with "there is already an object named".
   The database itself is created only if it does not already exist and
   is never dropped. Running this file three times in a row produces the
   same objects, the same row counts and the same test results.

   On line width: every hand-written line here stays at or under 78
   characters so the report can reproduce it as a Courier New 9 pt
   listing without wrapping. The generated data rows in section 4 run to
   86, which is what still fits in a 6.5 inch column at that size.

   The test queries are at the bottom, under SECTION 9: TESTS.
   ====================================================================== */

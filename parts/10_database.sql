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
   SECTION 1: CREATE THE DATABASE

   Named for the group, as the assignment requires. The group is
   E & D Group; the database is E_D_Group, because a SQL Server
   identifier cannot carry spaces or an ampersand without being
   bracketed at every single reference. Created only when it
   is missing, and never dropped. Dropping a database needs every other
   connection to it closed first, which a script cannot guarantee, and
   it would force a reconnect in the middle of this one. Re-runnability
   is handled a level down, by dropping and rebuilding the objects
   inside it, which section 2 does.
   ====================================================================== */

IF DB_ID('E_D_Group') IS NULL
    CREATE DATABASE E_D_Group;
GO

USE E_D_Group;
GO

/* =============================================================================
   Arquivo  : 00_setup/02_criar_schemas.sql
   Objetivo : Separar responsabilidades por schema.

     staging    -> dados como vieram do CSV (área de preparação)
     dw         -> modelo dimensional (dimensões e fato)
     etl        -> functions e procedures do processo de carga
     auditoria  -> log de execução de todas as etapas

   O SQL Server não tem PACKAGE como o Oracle. O papel de "pacote" (agrupar
   rotinas de um mesmo assunto sob um nome) fica com o schema etl.
   ============================================================================= */
USE PNAD_COVID;
GO

IF SCHEMA_ID(N'staging')   IS NULL EXEC (N'CREATE SCHEMA staging');
IF SCHEMA_ID(N'dw')        IS NULL EXEC (N'CREATE SCHEMA dw');
IF SCHEMA_ID(N'etl')       IS NULL EXEC (N'CREATE SCHEMA etl');
IF SCHEMA_ID(N'auditoria') IS NULL EXEC (N'CREATE SCHEMA auditoria');
GO

PRINT 'Schemas staging, dw, etl e auditoria prontos.';
GO

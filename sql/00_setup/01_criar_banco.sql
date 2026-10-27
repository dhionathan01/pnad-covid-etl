/* =============================================================================
   Projeto  : ETL PNAD Covid-19 (IBGE) -> SQL Server
   Arquivo  : 00_setup/01_criar_banco.sql
   Objetivo : Criar o banco PNAD_COVID.

   Por que a collation Latin1_General_CI_AI?
     - Latin1 (code page 1252) guarda acentos do português em VARCHAR.
     - CI (case insensitive) e AI (accent insensitive) deixam as comparações
       tolerantes: 'SAO PAULO' = 'São Paulo'. Onde precisamos de comparação
       exata (functions de texto), forçamos uma collation binária no código.
   ============================================================================= */
USE master;
GO

IF DB_ID(N'PNAD_COVID') IS NULL
BEGIN
    CREATE DATABASE PNAD_COVID COLLATE Latin1_General_CI_AI;
    PRINT 'Banco PNAD_COVID criado.';
END
ELSE
    PRINT 'Banco PNAD_COVID já existe.';
GO

-- Recovery SIMPLE: ambiente de estudo com cargas grandes; evita o log crescer sem backup.
ALTER DATABASE PNAD_COVID SET RECOVERY SIMPLE;
GO

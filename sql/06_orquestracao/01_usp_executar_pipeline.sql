/* =============================================================================
   Arquivo  : 06_orquestracao/01_usp_executar_pipeline.sql
   Objetivo : Rodar as etapas na ordem certa e limpar o ambiente para testes.

     etl.usp_executar_pipeline
       [@caminho_arquivo] -> etl.usp_carregar (opcional)
       etl.usp_carregar_dim_tempo
       etl.usp_carregar_dim_municipio
       etl.usp_carregar_dim_pessoa
       etl.usp_carregar_fato

     etl.usp_limpar_carga
       Esvazia staging, dimensões e fato e reinicia os IDENTITY.
       O log é preservado de propósito: ele é a evidência das execuções.

   Exemplos
     -- Um arquivo, do CSV até a fato:
     EXEC etl.usp_executar_pipeline @caminho_arquivo = N'/var/opt/mssql/dados/PNAD_COVID_112020.csv';

     -- Vários arquivos: carregue cada um com etl.usp_carregar e depois:
     EXEC etl.usp_executar_pipeline;
   ============================================================================= */
USE PNAD_COVID;
GO

CREATE OR ALTER PROCEDURE etl.usp_executar_pipeline
    @caminho_arquivo NVARCHAR(400) = NULL,
    @separador       CHAR(1)       = ','
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id_log     INT,
            @etapa      VARCHAR(50),
            @observacao VARCHAR(2000);

    EXEC auditoria.usp_log_iniciar
         @no_processo = 'etl.usp_executar_pipeline',
         @ds_arquivo  = @caminho_arquivo,
         @id_log      = @id_log OUTPUT;

    BEGIN TRY
        IF @caminho_arquivo IS NOT NULL
        BEGIN
            SET @etapa = 'usp_carregar';
            EXEC etl.usp_carregar @caminho_arquivo = @caminho_arquivo, @separador = @separador;
        END

        SET @etapa = 'usp_carregar_dim_tempo';
        EXEC etl.usp_carregar_dim_tempo;

        SET @etapa = 'usp_carregar_dim_municipio';
        EXEC etl.usp_carregar_dim_municipio;

        SET @etapa = 'usp_carregar_dim_pessoa';
        EXEC etl.usp_carregar_dim_pessoa;

        SET @etapa = 'usp_carregar_fato';
        EXEC etl.usp_carregar_fato;

        EXEC auditoria.usp_log_finalizar
             @id_log = @id_log, @st_execucao = 'SUCESSO',
             @ds_observacao = 'Todas as etapas concluídas. Contagens de cada etapa nas linhas de log anteriores.';
    END TRY
    BEGIN CATCH
        SET @observacao = CONCAT('Parou na etapa ', @etapa, ': ', ERROR_MESSAGE());
        EXEC auditoria.usp_log_finalizar
             @id_log = @id_log, @st_execucao = 'ERRO', @ds_observacao = @observacao;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE etl.usp_limpar_carga
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id_log INT;
    EXEC auditoria.usp_log_iniciar @no_processo = 'etl.usp_limpar_carga', @id_log = @id_log OUTPUT;

    BEGIN TRANSACTION;
        -- Fato primeiro, por causa das FKs.
        TRUNCATE TABLE dw.fato_pnad_covid;
        DELETE FROM dw.dim_pessoa;
        DELETE FROM dw.dim_municipio;
        DELETE FROM dw.dim_tempo;

        TRUNCATE TABLE staging.pnad_covid_pessoa;
        TRUNCATE TABLE staging.csv_bruto;
        DELETE FROM staging.pnad_covid_rejeitado;
    COMMIT TRANSACTION;

    -- Próximo IDENTITY volta a ser 1. Só reinicia tabela que já recebeu linha:
    -- numa tabela que nunca teve linha, RESEED 0 faria o primeiro sk ser 0.
    IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'dw.dim_tempo')) IS NOT NULL
        DBCC CHECKIDENT ('dw.dim_tempo', RESEED, 0) WITH NO_INFOMSGS;
    IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'dw.dim_municipio')) IS NOT NULL
        DBCC CHECKIDENT ('dw.dim_municipio', RESEED, 0) WITH NO_INFOMSGS;
    IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'dw.dim_pessoa')) IS NOT NULL
        DBCC CHECKIDENT ('dw.dim_pessoa', RESEED, 0) WITH NO_INFOMSGS;

    EXEC auditoria.usp_log_finalizar
         @id_log = @id_log, @st_execucao = 'SUCESSO',
         @ds_observacao = 'Staging, dimensões e fato esvaziadas. Log preservado.';
END
GO

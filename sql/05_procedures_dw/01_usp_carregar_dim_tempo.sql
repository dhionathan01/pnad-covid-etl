/* =============================================================================
   Arquivo  : 05_procedures_dw/01_usp_carregar_dim_tempo.sql
   Objetivo : etl.usp_carregar_dim_tempo

     - lê NU_ANO e NU_MES de staging.pnad_covid_pessoa
     - gera as combinações únicas de ano/mês
     - preenche no_mes com etl.fn_nome_mes
     - insere só o que ainda não existe (sem duplicidade)
   ============================================================================= */
USE PNAD_COVID;
GO

CREATE OR ALTER PROCEDURE etl.usp_carregar_dim_tempo
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id_log      INT,
            @qt_lidas    INT = 0,
            @qt_gravadas INT = 0,
            @observacao  VARCHAR(2000);

    EXEC auditoria.usp_log_iniciar @no_processo = 'etl.usp_carregar_dim_tempo', @id_log = @id_log OUTPUT;

    BEGIN TRY
        SELECT DISTINCT NU_ANO, NU_MES
        INTO #competencias
        FROM staging.pnad_covid_pessoa;

        SET @qt_lidas = @@ROWCOUNT;

        INSERT INTO dw.dim_tempo (nu_ano, nu_mes, no_mes)
        SELECT c.NU_ANO, c.NU_MES, etl.fn_nome_mes(c.NU_MES)
        FROM #competencias AS c
        WHERE NOT EXISTS (SELECT 1
                          FROM dw.dim_tempo AS d
                          WHERE d.nu_ano = c.NU_ANO
                            AND d.nu_mes = c.NU_MES);

        SET @qt_gravadas = @@ROWCOUNT;

        SET @observacao = CONCAT(@qt_lidas, ' competência(s) na staging; ',
                                 @qt_gravadas, ' nova(s); ',
                                 @qt_lidas - @qt_gravadas, ' já existia(m).');

        EXEC auditoria.usp_log_finalizar
             @id_log = @id_log, @qt_linhas_lidas = @qt_lidas, @qt_linhas_gravadas = @qt_gravadas,
             @st_execucao = 'SUCESSO', @ds_observacao = @observacao;

        PRINT 'usp_carregar_dim_tempo: ' + @observacao;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        SET @observacao = CONCAT('Erro ', ERROR_NUMBER(), ' (linha ', ERROR_LINE(), '): ', ERROR_MESSAGE());
        EXEC auditoria.usp_log_finalizar
             @id_log = @id_log, @qt_linhas_lidas = @qt_lidas, @qt_linhas_gravadas = 0,
             @st_execucao = 'ERRO', @ds_observacao = @observacao;
        THROW;
    END CATCH
END
GO

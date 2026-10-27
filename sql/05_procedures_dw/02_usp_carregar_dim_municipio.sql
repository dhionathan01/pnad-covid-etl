/* =============================================================================
   Arquivo  : 05_procedures_dw/02_usp_carregar_dim_municipio.sql
   Objetivo : etl.usp_carregar_dim_municipio

     - lê UF e CO_MUNICIPIO da staging
     - traduz e normaliza o nome (etl.fn_municipio_dw, que usa fn_nome_municipio
       e as functions de normalização textual)
     - insere apenas registros novos

   Por que aplicar as functions no DISTINCT e não em cada linha?
     A staging tem milhões de linhas, mas só umas 54 combinações de UF/capital.
     Chamar a function 54 vezes em vez de milhões é a diferença entre
     milissegundos e minutos.
   ============================================================================= */
USE PNAD_COVID;
GO

CREATE OR ALTER PROCEDURE etl.usp_carregar_dim_municipio
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id_log      INT,
            @qt_lidas    INT = 0,
            @qt_gravadas INT = 0,
            @observacao  VARCHAR(2000);

    EXEC auditoria.usp_log_iniciar @no_processo = 'etl.usp_carregar_dim_municipio', @id_log = @id_log OUTPUT;

    BEGIN TRY
        SELECT DISTINCT
               sg_uf        = etl.fn_sigla_uf(s.UF),
               no_municipio = etl.fn_municipio_dw(s.UF, s.CO_MUNICIPIO)
        INTO #municipios
        FROM (SELECT DISTINCT UF, CO_MUNICIPIO FROM staging.pnad_covid_pessoa) AS s;

        SET @qt_lidas = @@ROWCOUNT;

        INSERT INTO dw.dim_municipio (sg_uf, no_municipio)
        SELECT m.sg_uf, m.no_municipio
        FROM #municipios AS m
        WHERE NOT EXISTS (SELECT 1
                          FROM dw.dim_municipio AS d
                          WHERE d.sg_uf        = m.sg_uf
                            AND d.no_municipio = m.no_municipio);

        SET @qt_gravadas = @@ROWCOUNT;

        SET @observacao = CONCAT(@qt_lidas, ' município(s) distintos na staging; ',
                                 @qt_gravadas, ' novo(s); ',
                                 @qt_lidas - @qt_gravadas, ' já existia(m).');

        EXEC auditoria.usp_log_finalizar
             @id_log = @id_log, @qt_linhas_lidas = @qt_lidas, @qt_linhas_gravadas = @qt_gravadas,
             @st_execucao = 'SUCESSO', @ds_observacao = @observacao;

        PRINT 'usp_carregar_dim_municipio: ' + @observacao;
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

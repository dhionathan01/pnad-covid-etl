/* =============================================================================
   Arquivo  : 05_procedures_dw/03_usp_carregar_dim_pessoa.sql
   Objetivo : etl.usp_carregar_dim_pessoa

     - cria as faixas etárias (etl.fn_faixa_etaria)
     - padroniza sexo em M/F (etl.fn_sigla_sexo)
     - descrição de cor/raça (etl.fn_cor_raca)
     - descrição de escolaridade (etl.fn_escolaridade)
     - descrição da faixa de rendimento (etl.fn_faixa_rendimento)
     - insere apenas perfis novos

   Mesma ideia da dim_municipio: primeiro reduz a staging às combinações
   distintas de códigos (algumas dezenas de milhares), depois aplica as
   functions, e só então faz o DISTINCT final dos perfis.
   ============================================================================= */
USE PNAD_COVID;
GO

CREATE OR ALTER PROCEDURE etl.usp_carregar_dim_pessoa
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id_log      INT,
            @qt_lidas    INT = 0,
            @qt_gravadas INT = 0,
            @observacao  VARCHAR(2000);

    EXEC auditoria.usp_log_iniciar @no_processo = 'etl.usp_carregar_dim_pessoa', @id_log = @id_log OUTPUT;

    BEGIN TRY
        SELECT DISTINCT
               cor_raca         = etl.fn_cor_raca(c.COR_RACA),
               sexo             = etl.fn_sigla_sexo(c.SEXO),
               faixa_etaria     = etl.fn_faixa_etaria(c.IDADE),
               escolaridade     = etl.fn_escolaridade(c.ESCOLARIDADE),
               faixa_rendimento = etl.fn_faixa_rendimento(c.FAIXA_RENDIMENTO)
        INTO #perfis
        FROM (SELECT DISTINCT COR_RACA, SEXO, IDADE, ESCOLARIDADE, FAIXA_RENDIMENTO
              FROM staging.pnad_covid_pessoa) AS c;

        SET @qt_lidas = @@ROWCOUNT;

        INSERT INTO dw.dim_pessoa (cor_raca, sexo, faixa_etaria, escolaridade, faixa_rendimento)
        SELECT p.cor_raca, p.sexo, p.faixa_etaria, p.escolaridade, p.faixa_rendimento
        FROM #perfis AS p
        WHERE NOT EXISTS (SELECT 1
                          FROM dw.dim_pessoa AS d
                          WHERE d.cor_raca         = p.cor_raca
                            AND d.sexo             = p.sexo
                            AND d.faixa_etaria     = p.faixa_etaria
                            AND d.escolaridade     = p.escolaridade
                            AND d.faixa_rendimento = p.faixa_rendimento);

        SET @qt_gravadas = @@ROWCOUNT;

        SET @observacao = CONCAT(@qt_lidas, ' perfil(is) distintos na staging; ',
                                 @qt_gravadas, ' novo(s); ',
                                 @qt_lidas - @qt_gravadas, ' já existia(m).');

        EXEC auditoria.usp_log_finalizar
             @id_log = @id_log, @qt_linhas_lidas = @qt_lidas, @qt_linhas_gravadas = @qt_gravadas,
             @st_execucao = 'SUCESSO', @ds_observacao = @observacao;

        PRINT 'usp_carregar_dim_pessoa: ' + @observacao;
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

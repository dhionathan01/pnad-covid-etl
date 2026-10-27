/* =============================================================================
   Arquivo  : 05_procedures_dw/04_usp_carregar_fato.sql
   Objetivo : etl.usp_carregar_fato

     1. Resolve as chaves das dimensões
        - tempo ...... join direto por ano/mês
        - município .. mapa (UF, CO_MUNICIPIO) -> sk_municipio
        - pessoa ..... mapa (códigos da staging) -> sk_pessoa
     2. Agrega as métricas no grão mês x município x perfil
     3. Garante integridade referencial
        - linha da staging sem chave em alguma dimensão NÃO entra na fato
          e é contada no log (status SUCESSO PARCIAL)
        - as FKs da fato impedem gravar chave inexistente
     4. Recarga idempotente: apaga da fato os meses que estão sendo recarregados

   Métricas
     qt_pessoas ....... COUNT(*)
     atendimento_SUS .. ATENDIMENTO_SUS = 1 (buscou pronto socorro do SUS/UPA)
     internado ........ INTERNADO = 1
     sintoma .......... etl.fn_teve_sintoma(...) = 1 (ao menos um dos 12 sintomas)
   ============================================================================= */
USE PNAD_COVID;
GO

CREATE OR ALTER PROCEDURE etl.usp_carregar_fato
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id_log          INT,
            @qt_lidas        INT = 0,
            @qt_gravadas     INT = 0,
            @qt_sem_chave    INT = 0,
            @qt_pessoas_fato INT = 0,
            @status          VARCHAR(20),
            @observacao      VARCHAR(2000);

    EXEC auditoria.usp_log_iniciar @no_processo = 'etl.usp_carregar_fato', @id_log = @id_log OUTPUT;

    BEGIN TRY
        SELECT @qt_lidas = COUNT(*) FROM staging.pnad_covid_pessoa;

        /* ---------- 1. Mapas de chave ----------
           NULL não é igual a NULL num JOIN, então os códigos vazios viram -1
           tanto no mapa quanto na hora de ligar com a staging. */
        SELECT k.UF,
               k.co_municipio_chave,
               d.sk_municipio
        INTO #chave_municipio
        FROM (SELECT DISTINCT UF, CO_MUNICIPIO, co_municipio_chave = ISNULL(CO_MUNICIPIO, -1)
              FROM staging.pnad_covid_pessoa) AS k
        LEFT JOIN dw.dim_municipio AS d
               ON d.sg_uf        = etl.fn_sigla_uf(k.UF)
              AND d.no_municipio = etl.fn_municipio_dw(k.UF, k.CO_MUNICIPIO);

        SELECT k.cor_raca_chave, k.SEXO, k.IDADE, k.escolaridade_chave, k.faixa_rendimento_chave,
               d.sk_pessoa
        INTO #chave_pessoa
        FROM (SELECT DISTINCT
                     COR_RACA, SEXO, IDADE, ESCOLARIDADE, FAIXA_RENDIMENTO,
                     cor_raca_chave         = ISNULL(COR_RACA, -1),
                     escolaridade_chave     = ISNULL(ESCOLARIDADE, -1),
                     faixa_rendimento_chave = ISNULL(FAIXA_RENDIMENTO, -1)
              FROM staging.pnad_covid_pessoa) AS k
        LEFT JOIN dw.dim_pessoa AS d
               ON d.cor_raca         = etl.fn_cor_raca(k.COR_RACA)
              AND d.sexo             = etl.fn_sigla_sexo(k.SEXO)
              AND d.faixa_etaria     = etl.fn_faixa_etaria(k.IDADE)
              AND d.escolaridade     = etl.fn_escolaridade(k.ESCOLARIDADE)
              AND d.faixa_rendimento = etl.fn_faixa_rendimento(k.FAIXA_RENDIMENTO);

        CREATE UNIQUE CLUSTERED INDEX ix_chave_municipio ON #chave_municipio (UF, co_municipio_chave);
        CREATE UNIQUE CLUSTERED INDEX ix_chave_pessoa
            ON #chave_pessoa (cor_raca_chave, SEXO, IDADE, escolaridade_chave, faixa_rendimento_chave);

        /* ---------- 2. Agregação ---------- */
        SELECT t.sk_tempo,
               cm.sk_municipio,
               cp.sk_pessoa,
               qt_pessoas      = COUNT(*),
               atendimento_SUS = SUM(CASE WHEN s.ATENDIMENTO_SUS = 1 THEN 1 ELSE 0 END),
               internado       = SUM(CASE WHEN s.INTERNADO = 1 THEN 1 ELSE 0 END),
               sintoma         = SUM(etl.fn_teve_sintoma(
                                     s.SINTOMA_FEBRE, s.SINTOMA_TOSSE, s.SINTOMA_DOR_GARGANTA,
                                     s.SINTOMA_DIFICULDADE_RESPIRAR, s.SINTOMA_DOR_CABECA,
                                     s.SINTOMA_DOR_PEITO, s.SINTOMA_NAUSEA, s.SINTOMA_NARIZ,
                                     s.SINTOMA_FADIGA, s.SINTOMA_DOR_OLHOS,
                                     s.SINTOMA_PERDA_CHEIRO_SABOR, s.SINTOMA_DOR_MUSCULAR))
        INTO #fato
        FROM staging.pnad_covid_pessoa AS s
        LEFT JOIN dw.dim_tempo AS t
               ON t.nu_ano = s.NU_ANO
              AND t.nu_mes = s.NU_MES
        LEFT JOIN #chave_municipio AS cm
               ON cm.UF                 = s.UF
              AND cm.co_municipio_chave = ISNULL(s.CO_MUNICIPIO, -1)
        LEFT JOIN #chave_pessoa AS cp
               ON cp.cor_raca_chave         = ISNULL(s.COR_RACA, -1)
              AND cp.SEXO                   = s.SEXO
              AND cp.IDADE                  = s.IDADE
              AND cp.escolaridade_chave     = ISNULL(s.ESCOLARIDADE, -1)
              AND cp.faixa_rendimento_chave = ISNULL(s.FAIXA_RENDIMENTO, -1)
        GROUP BY t.sk_tempo, cm.sk_municipio, cp.sk_pessoa;

        /* ---------- 3. Integridade referencial ---------- */
        SELECT @qt_sem_chave = ISNULL(SUM(qt_pessoas), 0)
        FROM #fato
        WHERE sk_tempo IS NULL OR sk_municipio IS NULL OR sk_pessoa IS NULL;

        /* ---------- 4. Gravação ---------- */
        BEGIN TRANSACTION;

            DELETE f
            FROM dw.fato_pnad_covid AS f
            WHERE f.sk_tempo IN (SELECT sk_tempo FROM #fato WHERE sk_tempo IS NOT NULL);

            INSERT INTO dw.fato_pnad_covid
                (sk_tempo, sk_municipio, sk_pessoa, qt_pessoas, atendimento_SUS, internado, sintoma)
            SELECT sk_tempo, sk_municipio, sk_pessoa, qt_pessoas, atendimento_SUS, internado, sintoma
            FROM #fato
            WHERE sk_tempo     IS NOT NULL
              AND sk_municipio IS NOT NULL
              AND sk_pessoa    IS NOT NULL;

            SET @qt_gravadas = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT @qt_pessoas_fato = ISNULL(SUM(qt_pessoas), 0)
        FROM #fato
        WHERE sk_tempo IS NOT NULL AND sk_municipio IS NOT NULL AND sk_pessoa IS NOT NULL;

        SET @status = CASE
                          WHEN @qt_lidas = 0      THEN 'ERRO'
                          WHEN @qt_sem_chave = 0  THEN 'SUCESSO'
                          WHEN @qt_gravadas > 0   THEN 'SUCESSO PARCIAL'
                          ELSE 'ERRO'
                      END;

        SET @observacao = CONCAT(
            'Linhas da staging: ', @qt_lidas,
            ' | Pessoas agregadas na fato: ', @qt_pessoas_fato,
            ' | Linhas na fato (grão mês x município x perfil): ', @qt_gravadas,
            CASE WHEN @qt_sem_chave > 0
                 THEN CONCAT(' | Pessoas sem chave em alguma dimensão (fora da fato): ', @qt_sem_chave,
                             '. Rode as cargas das dimensões antes da fato.')
                 WHEN @qt_lidas = 0 THEN ' | Staging vazia.'
                 ELSE '' END);

        EXEC auditoria.usp_log_finalizar
             @id_log = @id_log, @qt_linhas_lidas = @qt_lidas, @qt_linhas_gravadas = @qt_gravadas,
             @st_execucao = @status, @ds_observacao = @observacao;

        PRINT 'usp_carregar_fato: ' + @status + ' | ' + @observacao;
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

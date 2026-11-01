/* =============================================================================
   Arquivo  : 03_staging/02_usp_carregar.sql
   Objetivo : etl.usp_carregar, carga do CSV do IBGE para a staging.

   Etapas
     1. Leitura .... BULK INSERT do arquivo inteiro em staging.csv_bruto (1 linha = 1 registro)
     2. Cabeçalho .. localiza as colunas pelo nome usando staging.mapa_coluna_csv
     3. Extração ... quebra cada linha em campos (OPENJSON) e guarda como texto em #brutas
     4. Validação .. converte tipos e aplica as regras; cada linha ganha um motivo de rejeição (ou nenhum)
     5. Gravação ... em uma transação: apaga a competência (permite reprocessar),
                     grava as válidas na staging e as inválidas em staging.pnad_covid_rejeitado
     6. Log ........ data/hora, linhas lidas, linhas gravadas, status e observação

   Status
     SUCESSO ......... todas as linhas lidas foram gravadas
     SUCESSO PARCIAL . parte das linhas foi rejeitada
     ERRO ............ nenhuma linha gravada ou falha na execução

   Por que OPENJSON para quebrar a linha?
     "2020,11,11,,1" vira o array JSON ["2020","11","11","","1"], que vai
     embrulhado em [[...]], e o OPENJSON ... WITH ('$[0]', '$[6]'...) devolve
     cada posição como coluna numa única passada pela linha. É bem mais
     rápido que STRING_SPLIT para arquivos com centenas de milhares de linhas
     e funciona a partir do SQL Server 2016.

   Exemplo
     EXEC etl.usp_carregar @caminho_arquivo = N'/var/opt/mssql/dados/PNAD_COVID_112020.csv';
     -- SQL Server no Windows:
     EXEC etl.usp_carregar @caminho_arquivo = N'C:\pnad\dados\PNAD_COVID_112020.csv';
   ============================================================================= */
USE PNAD_COVID;
GO

CREATE OR ALTER PROCEDURE etl.usp_carregar
    @caminho_arquivo NVARCHAR(400),
    @separador       CHAR(1) = ','
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;   -- qualquer erro dentro da transação desfaz tudo

    DECLARE @id_log          INT,
            @qt_lidas        INT = 0,
            @qt_gravadas     INT = 0,
            @qt_rejeitadas   INT = 0,
            @id_cabecalho    INT,
            @cabecalho       VARCHAR(MAX),
            @faltantes       VARCHAR(1000),
            @colunas_with    NVARCHAR(MAX),
            @colunas_insert  NVARCHAR(MAX),
            @sql             NVARCHAR(MAX),
            @mensagem        NVARCHAR(2048),
            @competencias    VARCHAR(500),
            @principal_motivo VARCHAR(500),
            @status          VARCHAR(20),
            @observacao      VARCHAR(2000);

    EXEC auditoria.usp_log_iniciar
         @no_processo = 'etl.usp_carregar',
         @ds_arquivo  = @caminho_arquivo,
         @id_log      = @id_log OUTPUT;

    BEGIN TRY
        /* ================= 1. Leitura do arquivo ================= */
        TRUNCATE TABLE staging.csv_bruto;

        -- O caminho vem de parâmetro, então o BULK INSERT precisa de SQL dinâmico.
        -- REPLACE dobra apóstrofos do caminho para não quebrar a string.
        SET @sql = N'BULK INSERT staging.vw_csv_bruto FROM '''
                 + REPLACE(@caminho_arquivo, N'''', N'''''')
                 + N''' WITH (ROWTERMINATOR = ''0x0a'', DATAFILETYPE = ''char'', TABLOCK);';
        EXEC sys.sp_executesql @sql;

        /* ================= 2. Cabeçalho ================= */
        SELECT TOP (1)
               @id_cabecalho = id_linha,
               @cabecalho    = ds_linha
        FROM staging.csv_bruto
        WHERE ds_linha LIKE '%Ano%'
          AND ds_linha LIKE '%V1013%'
          AND ds_linha LIKE '%A002%'
        ORDER BY id_linha;

        IF @id_cabecalho IS NULL
            THROW 50001, N'Cabeçalho do CSV não encontrado (esperado: Ano, UF, V1013, A002...).', 1;

        -- Remove aspas, CR do Windows e qualquer lixo antes de "Ano" (ex.: BOM do UTF-8).
        SET @cabecalho = REPLACE(REPLACE(@cabecalho, '"', ''), CHAR(13), '');
        SET @cabecalho = SUBSTRING(@cabecalho, CHARINDEX('Ano', @cabecalho), LEN(@cabecalho));

        -- Nome da coluna -> posição (0, 1, 2...) no arquivo.
        DECLARE @colunas TABLE (no_coluna VARCHAR(50) NOT NULL PRIMARY KEY, nu_posicao INT NOT NULL);

        INSERT INTO @colunas (no_coluna, nu_posicao)
        SELECT UPPER(LTRIM(RTRIM(c.[value]))), MIN(CAST(c.[key] AS INT))
        FROM OPENJSON('["' + REPLACE(@cabecalho, @separador, '","') + '"]') AS c
        GROUP BY UPPER(LTRIM(RTRIM(c.[value])));

        -- Toda coluna do de-para precisa existir no arquivo.
        SELECT @faltantes = STRING_AGG(m.no_coluna_origem, ', ') WITHIN GROUP (ORDER BY m.nu_ordem)
        FROM staging.mapa_coluna_csv AS m
        LEFT JOIN @colunas AS c ON c.no_coluna = m.no_coluna_origem
        WHERE c.no_coluna IS NULL;

        IF @faltantes IS NOT NULL
        BEGIN
            SET @mensagem = N'Colunas obrigatórias ausentes no CSV: ' + @faltantes;
            THROW 50002, @mensagem, 1;
        END

        /* ================= 3. Extração dos campos ================= */
        -- Monta, a partir do de-para, algo como:
        --   [NU_ANO] VARCHAR(30) '$[0]', [NU_MES] VARCHAR(30) '$[6]', ...
        SELECT @colunas_with = STRING_AGG(
                   CAST(QUOTENAME(m.no_coluna_destino) + N' VARCHAR(30) ''$['
                        + CAST(c.nu_posicao AS NVARCHAR(10)) + N']''' AS NVARCHAR(MAX)), N', ')
                   WITHIN GROUP (ORDER BY m.nu_ordem),
               @colunas_insert = STRING_AGG(CAST(QUOTENAME(m.no_coluna_destino) AS NVARCHAR(MAX)), N', ')
                   WITHIN GROUP (ORDER BY m.nu_ordem)
        FROM staging.mapa_coluna_csv AS m
        JOIN @colunas AS c ON c.no_coluna = m.no_coluna_origem;

        -- Campos ainda como texto: a conversão acontece na validação,
        -- assim um valor inválido vira motivo de rejeição e não derruba a carga.
        CREATE TABLE #brutas
        (
            nu_linha                      INT         NOT NULL,
            fl_linha_valida               BIT         NOT NULL,
            NU_ANO                        VARCHAR(30) NULL,
            NU_MES                        VARCHAR(30) NULL,
            UF                            VARCHAR(30) NULL,
            CO_MUNICIPIO                  VARCHAR(30) NULL,
            COR_RACA                      VARCHAR(30) NULL,
            SEXO                          VARCHAR(30) NULL,
            IDADE                         VARCHAR(30) NULL,
            ESCOLARIDADE                  VARCHAR(30) NULL,
            FAIXA_RENDIMENTO              VARCHAR(30) NULL,
            ATENDIMENTO_SUS               VARCHAR(30) NULL,
            INTERNADO                     VARCHAR(30) NULL,
            SINTOMA_FEBRE                 VARCHAR(30) NULL,
            SINTOMA_TOSSE                 VARCHAR(30) NULL,
            SINTOMA_DOR_GARGANTA          VARCHAR(30) NULL,
            SINTOMA_DIFICULDADE_RESPIRAR  VARCHAR(30) NULL,
            SINTOMA_DOR_CABECA            VARCHAR(30) NULL,
            SINTOMA_DOR_PEITO             VARCHAR(30) NULL,
            SINTOMA_NAUSEA                VARCHAR(30) NULL,
            SINTOMA_NARIZ                 VARCHAR(30) NULL,
            SINTOMA_FADIGA                VARCHAR(30) NULL,
            SINTOMA_DOR_OLHOS             VARCHAR(30) NULL,
            SINTOMA_PERDA_CHEIRO_SABOR    VARCHAR(30) NULL,
            SINTOMA_DOR_MUSCULAR          VARCHAR(30) NULL
        );

        -- Linha que não vira JSON válido (caractere estranho, aspas quebradas)
        -- passa um array vazio para o OPENJSON: os campos ficam NULL e a
        -- validação rejeita a linha como "mal formada", sem derrubar a carga.
        -- O array da linha vai dentro de outro array ([[...]]): OPENJSON sobre
        -- um array devolve uma linha por elemento, então o externo precisa ter
        -- um elemento só para '$[n]' apontar para a posição n da linha.
        -- COLLATE BIN2 no REPLACE: comparar byte a byte é muito mais rápido que
        -- pela collation CI_AI da coluna, e aqui não há acento a comparar.
        SET @sql = N'
INSERT INTO #brutas (nu_linha, fl_linha_valida, ' + @colunas_insert + N')
SELECT b.id_linha, CAST(ISJSON(x.ds_json) AS BIT), j.*
FROM staging.csv_bruto AS b
CROSS APPLY (SELECT ds_json = ''["'' + REPLACE(REPLACE(REPLACE(b.ds_linha COLLATE Latin1_General_BIN2, ''"'', ''''), CHAR(13), ''''), @sep, ''","'') + ''"]'') AS x
OUTER APPLY OPENJSON(CASE WHEN ISJSON(x.ds_json) = 1 THEN ''['' + x.ds_json + '']'' ELSE ''[]'' END)
     WITH (' + @colunas_with + N') AS j
WHERE b.id_linha <> @id_cab
  AND LEN(REPLACE(b.ds_linha, CHAR(13), '''')) > 0;';

        EXEC sys.sp_executesql @sql,
             N'@sep CHAR(1), @id_cab INT',
             @sep = @separador, @id_cab = @id_cabecalho;

        SELECT @qt_lidas = COUNT(*) FROM #brutas;

        IF @qt_lidas = 0
            THROW 50003, N'O arquivo não tem linhas de dados depois do cabeçalho.', 1;

        /* ================= 4. Validação ================= */
        SELECT  b.nu_linha,
                v.*,
                -- Linha que nem chegou a ser quebrada em campos tem um motivo só.
                -- Nas demais, CONCAT_WS junta todos os motivos encontrados e
                -- devolve '' quando a linha passou em todas as regras.
                ds_motivo = CASE
                WHEN b.fl_linha_valida = 0 OR b.NU_ANO IS NULL
                    THEN 'linha mal formada (não foi possível separar os campos)'
                ELSE CONCAT_WS('; ',
                    CASE WHEN v.NU_ANO IS NULL
                         THEN 'NU_ANO ausente ou não numérico' END,
                    CASE WHEN v.NU_MES IS NULL OR v.NU_MES NOT BETWEEN 1 AND 12
                         THEN 'NU_MES fora de 1 a 12' END,
                    CASE WHEN etl.fn_sigla_uf(v.UF) IS NULL
                         THEN 'UF inexistente' END,
                    CASE WHEN v.IDADE IS NULL OR v.IDADE NOT BETWEEN 0 AND 130
                         THEN 'IDADE ausente ou fora de 0 a 130' END,
                    CASE WHEN v.SEXO IS NULL OR v.SEXO NOT IN (1, 2)
                         THEN 'SEXO diferente de 1 ou 2' END,
                    CASE WHEN v.CO_MUNICIPIO IS NOT NULL AND v.CO_MUNICIPIO <> v.UF
                         THEN 'CO_MUNICIPIO não corresponde à capital da UF' END,
                    -- Campo de código preenchido que não converteu para número
                    CASE WHEN (NULLIF(b.CO_MUNICIPIO, '') IS NOT NULL AND v.CO_MUNICIPIO IS NULL)
                           OR (NULLIF(b.COR_RACA, '') IS NOT NULL AND v.COR_RACA IS NULL)
                           OR (NULLIF(b.ESCOLARIDADE, '') IS NOT NULL AND v.ESCOLARIDADE IS NULL)
                           OR (NULLIF(b.FAIXA_RENDIMENTO, '') IS NOT NULL AND v.FAIXA_RENDIMENTO IS NULL)
                           OR (NULLIF(b.ATENDIMENTO_SUS, '') IS NOT NULL AND v.ATENDIMENTO_SUS IS NULL)
                           OR (NULLIF(b.INTERNADO, '') IS NOT NULL AND v.INTERNADO IS NULL)
                           OR (NULLIF(b.SINTOMA_FEBRE, '') IS NOT NULL AND v.SINTOMA_FEBRE IS NULL)
                           OR (NULLIF(b.SINTOMA_TOSSE, '') IS NOT NULL AND v.SINTOMA_TOSSE IS NULL)
                           OR (NULLIF(b.SINTOMA_DOR_GARGANTA, '') IS NOT NULL AND v.SINTOMA_DOR_GARGANTA IS NULL)
                           OR (NULLIF(b.SINTOMA_DIFICULDADE_RESPIRAR, '') IS NOT NULL AND v.SINTOMA_DIFICULDADE_RESPIRAR IS NULL)
                           OR (NULLIF(b.SINTOMA_DOR_CABECA, '') IS NOT NULL AND v.SINTOMA_DOR_CABECA IS NULL)
                           OR (NULLIF(b.SINTOMA_DOR_PEITO, '') IS NOT NULL AND v.SINTOMA_DOR_PEITO IS NULL)
                           OR (NULLIF(b.SINTOMA_NAUSEA, '') IS NOT NULL AND v.SINTOMA_NAUSEA IS NULL)
                           OR (NULLIF(b.SINTOMA_NARIZ, '') IS NOT NULL AND v.SINTOMA_NARIZ IS NULL)
                           OR (NULLIF(b.SINTOMA_FADIGA, '') IS NOT NULL AND v.SINTOMA_FADIGA IS NULL)
                           OR (NULLIF(b.SINTOMA_DOR_OLHOS, '') IS NOT NULL AND v.SINTOMA_DOR_OLHOS IS NULL)
                           OR (NULLIF(b.SINTOMA_PERDA_CHEIRO_SABOR, '') IS NOT NULL AND v.SINTOMA_PERDA_CHEIRO_SABOR IS NULL)
                           OR (NULLIF(b.SINTOMA_DOR_MUSCULAR, '') IS NOT NULL AND v.SINTOMA_DOR_MUSCULAR IS NULL)
                         THEN 'campo de código com valor não numérico' END
                )
                END
        INTO #validadas
        FROM #brutas AS b
        -- NULLIF(...,'') antes do TRY_CAST: TRY_CAST('' AS INT) devolve 0, não NULL.
        CROSS APPLY (SELECT
                NU_ANO                       = TRY_CAST(NULLIF(LTRIM(RTRIM(b.NU_ANO)), '') AS INT),
                NU_MES                       = TRY_CAST(NULLIF(LTRIM(RTRIM(b.NU_MES)), '') AS INT),
                UF                           = TRY_CAST(NULLIF(LTRIM(RTRIM(b.UF)), '') AS INT),
                CO_MUNICIPIO                 = TRY_CAST(NULLIF(LTRIM(RTRIM(b.CO_MUNICIPIO)), '') AS INT),
                COR_RACA                     = TRY_CAST(NULLIF(LTRIM(RTRIM(b.COR_RACA)), '') AS INT),
                SEXO                         = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SEXO)), '') AS INT),
                IDADE                        = TRY_CAST(NULLIF(LTRIM(RTRIM(b.IDADE)), '') AS INT),
                ESCOLARIDADE                 = TRY_CAST(NULLIF(LTRIM(RTRIM(b.ESCOLARIDADE)), '') AS INT),
                FAIXA_RENDIMENTO             = TRY_CAST(NULLIF(LTRIM(RTRIM(b.FAIXA_RENDIMENTO)), '') AS INT),
                ATENDIMENTO_SUS              = TRY_CAST(NULLIF(LTRIM(RTRIM(b.ATENDIMENTO_SUS)), '') AS INT),
                INTERNADO                    = TRY_CAST(NULLIF(LTRIM(RTRIM(b.INTERNADO)), '') AS INT),
                SINTOMA_FEBRE                = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SINTOMA_FEBRE)), '') AS INT),
                SINTOMA_TOSSE                = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SINTOMA_TOSSE)), '') AS INT),
                SINTOMA_DOR_GARGANTA         = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SINTOMA_DOR_GARGANTA)), '') AS INT),
                SINTOMA_DIFICULDADE_RESPIRAR = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SINTOMA_DIFICULDADE_RESPIRAR)), '') AS INT),
                SINTOMA_DOR_CABECA           = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SINTOMA_DOR_CABECA)), '') AS INT),
                SINTOMA_DOR_PEITO            = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SINTOMA_DOR_PEITO)), '') AS INT),
                SINTOMA_NAUSEA               = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SINTOMA_NAUSEA)), '') AS INT),
                SINTOMA_NARIZ                = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SINTOMA_NARIZ)), '') AS INT),
                SINTOMA_FADIGA               = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SINTOMA_FADIGA)), '') AS INT),
                SINTOMA_DOR_OLHOS            = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SINTOMA_DOR_OLHOS)), '') AS INT),
                SINTOMA_PERDA_CHEIRO_SABOR   = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SINTOMA_PERDA_CHEIRO_SABOR)), '') AS INT),
                SINTOMA_DOR_MUSCULAR         = TRY_CAST(NULLIF(LTRIM(RTRIM(b.SINTOMA_DOR_MUSCULAR)), '') AS INT)
        ) AS v;

        /* ================= 5. Gravação ================= */
        BEGIN TRANSACTION;

            -- Reprocessamento: se a competência (ano/mês) já estava na staging, sai a versão antiga.
            DELETE s
            FROM staging.pnad_covid_pessoa AS s
            WHERE EXISTS (SELECT 1
                          FROM #validadas AS v
                          WHERE v.ds_motivo = ''
                            AND v.NU_ANO = s.NU_ANO
                            AND v.NU_MES = s.NU_MES);

            INSERT INTO staging.pnad_covid_pessoa
            (
                NU_ANO, NU_MES, UF, CO_MUNICIPIO, COR_RACA, SEXO, IDADE, ESCOLARIDADE,
                FAIXA_RENDIMENTO, ATENDIMENTO_SUS, INTERNADO,
                SINTOMA_FEBRE, SINTOMA_TOSSE, SINTOMA_DOR_GARGANTA, SINTOMA_DIFICULDADE_RESPIRAR,
                SINTOMA_DOR_CABECA, SINTOMA_DOR_PEITO, SINTOMA_NAUSEA, SINTOMA_NARIZ,
                SINTOMA_FADIGA, SINTOMA_DOR_OLHOS, SINTOMA_PERDA_CHEIRO_SABOR, SINTOMA_DOR_MUSCULAR,
                DT_CARGA, ID_LOG
            )
            SELECT
                NU_ANO, NU_MES, UF, CO_MUNICIPIO, COR_RACA, SEXO, IDADE, ESCOLARIDADE,
                FAIXA_RENDIMENTO, ATENDIMENTO_SUS, INTERNADO,
                SINTOMA_FEBRE, SINTOMA_TOSSE, SINTOMA_DOR_GARGANTA, SINTOMA_DIFICULDADE_RESPIRAR,
                SINTOMA_DOR_CABECA, SINTOMA_DOR_PEITO, SINTOMA_NAUSEA, SINTOMA_NARIZ,
                SINTOMA_FADIGA, SINTOMA_DOR_OLHOS, SINTOMA_PERDA_CHEIRO_SABOR, SINTOMA_DOR_MUSCULAR,
                GETDATE(), @id_log
            FROM #validadas
            WHERE ds_motivo = '';

            SET @qt_gravadas = @@ROWCOUNT;

            INSERT INTO staging.pnad_covid_rejeitado (id_log, nu_linha, ds_motivo, ds_linha)
            SELECT @id_log, v.nu_linha, v.ds_motivo, b.ds_linha
            FROM #validadas AS v
            JOIN staging.csv_bruto AS b ON b.id_linha = v.nu_linha
            WHERE v.ds_motivo <> '';

            SET @qt_rejeitadas = @@ROWCOUNT;

        COMMIT TRANSACTION;

        /* ================= 6. Log ================= */
        SELECT @competencias = STRING_AGG(c.competencia, ', ') WITHIN GROUP (ORDER BY c.competencia)
        FROM (SELECT DISTINCT competencia = CONCAT(NU_ANO, '-', RIGHT('0' + CAST(NU_MES AS VARCHAR(2)), 2))
              FROM #validadas
              WHERE ds_motivo = '') AS c;

        SELECT TOP (1) @principal_motivo = CONCAT(ds_motivo, ' (', COUNT(*), ')')
        FROM #validadas
        WHERE ds_motivo <> ''
        GROUP BY ds_motivo
        ORDER BY COUNT(*) DESC;

        SET @status = CASE
                          WHEN @qt_gravadas = @qt_lidas THEN 'SUCESSO'
                          WHEN @qt_gravadas > 0         THEN 'SUCESSO PARCIAL'
                          ELSE 'ERRO'
                      END;

        SET @observacao = CONCAT(
            'Competências: ', ISNULL(@competencias, 'nenhuma'),
            ' | Rejeitadas: ', @qt_rejeitadas,
            CASE WHEN @qt_rejeitadas > 0
                 THEN CONCAT(' | Principal motivo: ', @principal_motivo,
                             ' | Detalhes: staging.pnad_covid_rejeitado WHERE id_log = ', @id_log)
                 ELSE '' END);

        EXEC auditoria.usp_log_finalizar
             @id_log             = @id_log,
             @qt_linhas_lidas    = @qt_lidas,
             @qt_linhas_gravadas = @qt_gravadas,
             @st_execucao        = @status,
             @ds_observacao      = @observacao;

        -- O texto bruto já cumpriu seu papel (as rejeitadas guardam a própria linha).
        TRUNCATE TABLE staging.csv_bruto;

        PRINT CONCAT('usp_carregar: ', @status, ' | lidas: ', @qt_lidas,
                     ' | gravadas: ', @qt_gravadas, ' | rejeitadas: ', @qt_rejeitadas);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        SET @observacao = CONCAT('Erro ', ERROR_NUMBER(), ' (linha ', ERROR_LINE(), '): ', ERROR_MESSAGE());

        EXEC auditoria.usp_log_finalizar
             @id_log             = @id_log,
             @qt_linhas_lidas    = @qt_lidas,
             @qt_linhas_gravadas = 0,
             @st_execucao        = 'ERRO',
             @ds_observacao      = @observacao;

        THROW;
    END CATCH

    -- Nenhuma linha aproveitável também é erro para quem chamou (o script para ou avisa).
    IF @status = 'ERRO'
        THROW 50004, N'Nenhuma linha válida foi gravada. Veja auditoria.log_execucao.', 1;
END
GO

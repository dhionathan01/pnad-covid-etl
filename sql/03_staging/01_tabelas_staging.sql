/* =============================================================================
   Arquivo  : 03_staging/01_tabelas_staging.sql
   Objetivo : Estruturas da área de staging.

     staging.csv_bruto            -> cada linha do CSV como texto, exatamente como veio
     staging.vw_csv_bruto         -> view usada pelo BULK INSERT (esconde a coluna IDENTITY)
     staging.mapa_coluna_csv      -> de-para: coluna do IBGE -> coluna da staging
     staging.pnad_covid_pessoa    -> linhas válidas, já com tipos corretos (modelo do enunciado)
     staging.pnad_covid_rejeitado -> linhas que falharam na validação e o motivo
   ============================================================================= */
USE PNAD_COVID;
GO

/* ---------- Arquivo bruto ---------- */
IF OBJECT_ID(N'staging.csv_bruto', N'U') IS NULL
BEGIN
    CREATE TABLE staging.csv_bruto
    (
        id_linha  INT IDENTITY(1, 1) NOT NULL,
        ds_linha  VARCHAR(MAX)       NULL,
        CONSTRAINT pk_csv_bruto PRIMARY KEY CLUSTERED (id_linha)
    );
END
GO

-- O BULK INSERT grava numa view com só a coluna de texto; o IDENTITY da tabela
-- numera as linhas sozinho. Sem a view, o BULK INSERT exigiria um format file.
CREATE OR ALTER VIEW staging.vw_csv_bruto
AS
SELECT ds_linha
FROM staging.csv_bruto;
GO

/* ---------- De-para das colunas ----------
   Ler as colunas pelo NOME do cabeçalho (e não pela posição) deixa a carga
   resistente a arquivos de meses diferentes, em que o IBGE incluiu perguntas
   novas e as posições mudaram. */
IF OBJECT_ID(N'staging.mapa_coluna_csv', N'U') IS NULL
BEGIN
    CREATE TABLE staging.mapa_coluna_csv
    (
        nu_ordem           INT          NOT NULL,
        no_coluna_destino  VARCHAR(50)  NOT NULL,
        no_coluna_origem   VARCHAR(50)  NOT NULL,
        ds_pergunta        VARCHAR(200) NOT NULL,
        CONSTRAINT pk_mapa_coluna_csv PRIMARY KEY CLUSTERED (no_coluna_destino),
        CONSTRAINT uq_mapa_coluna_csv_ordem UNIQUE (nu_ordem)
    );
END
GO

MERGE staging.mapa_coluna_csv AS alvo
USING (VALUES
    ( 1, 'NU_ANO',                        'ANO',     'Ano de referência'),
    ( 2, 'NU_MES',                        'V1013',   'Mês da pesquisa'),
    ( 3, 'UF',                            'UF',      'Unidade da Federação'),
    ( 4, 'CO_MUNICIPIO',                  'CAPITAL', 'Capital (código da UF quando mora na capital)'),
    ( 5, 'COR_RACA',                      'A004',    'Cor ou raça'),
    ( 6, 'SEXO',                          'A003',    'Sexo'),
    ( 7, 'IDADE',                         'A002',    'Idade do morador'),
    ( 8, 'ESCOLARIDADE',                  'A005',    'Escolaridade'),
    ( 9, 'FAIXA_RENDIMENTO',              'C01011',  'Faixa do rendimento/retirada em dinheiro'),
    (10, 'ATENDIMENTO_SUS',               'B0042',   'Local que buscou atendimento: pronto socorro do SUS/UPA'),
    (11, 'INTERNADO',                     'B005',    'Ao procurar o hospital, teve que ficar internado'),
    (12, 'SINTOMA_FEBRE',                 'B0011',   'Na semana passada teve febre?'),
    (13, 'SINTOMA_TOSSE',                 'B0012',   'Na semana passada teve tosse?'),
    (14, 'SINTOMA_DOR_GARGANTA',          'B0013',   'Na semana passada teve dor de garganta?'),
    (15, 'SINTOMA_DIFICULDADE_RESPIRAR',  'B0014',   'Na semana passada teve dificuldade para respirar?'),
    (16, 'SINTOMA_DOR_CABECA',            'B0015',   'Na semana passada teve dor de cabeça?'),
    (17, 'SINTOMA_DOR_PEITO',             'B0016',   'Na semana passada teve dor no peito?'),
    (18, 'SINTOMA_NAUSEA',                'B0017',   'Na semana passada teve náusea?'),
    (19, 'SINTOMA_NARIZ',                 'B0018',   'Na semana passada teve nariz entupido ou escorrendo?'),
    (20, 'SINTOMA_FADIGA',                'B0019',   'Na semana passada teve fadiga?'),
    (21, 'SINTOMA_DOR_OLHOS',             'B00110',  'Na semana passada teve dor nos olhos?'),
    (22, 'SINTOMA_PERDA_CHEIRO_SABOR',    'B00111',  'Na semana passada teve perda de cheiro ou sabor?'),
    (23, 'SINTOMA_DOR_MUSCULAR',          'B00112',  'Na semana passada teve dor muscular?')
) AS origem (nu_ordem, no_coluna_destino, no_coluna_origem, ds_pergunta)
ON alvo.no_coluna_destino = origem.no_coluna_destino
WHEN MATCHED THEN
    UPDATE SET nu_ordem         = origem.nu_ordem,
               no_coluna_origem = origem.no_coluna_origem,
               ds_pergunta      = origem.ds_pergunta
WHEN NOT MATCHED BY TARGET THEN
    INSERT (nu_ordem, no_coluna_destino, no_coluna_origem, ds_pergunta)
    VALUES (origem.nu_ordem, origem.no_coluna_destino, origem.no_coluna_origem, origem.ds_pergunta);
GO

/* ---------- Staging tipada (modelo do enunciado) ----------
   ID_LOG é um acréscimo: liga cada linha à execução que a gravou. */
IF OBJECT_ID(N'staging.pnad_covid_pessoa', N'U') IS NULL
BEGIN
    CREATE TABLE staging.pnad_covid_pessoa
    (
        NU_ANO                        INT      NOT NULL,
        NU_MES                        INT      NOT NULL,
        UF                            INT      NOT NULL,
        CO_MUNICIPIO                  INT      NULL,
        COR_RACA                      INT      NULL,
        SEXO                          INT      NOT NULL,
        IDADE                         INT      NOT NULL,
        ESCOLARIDADE                  INT      NULL,
        FAIXA_RENDIMENTO              INT      NULL,
        ATENDIMENTO_SUS               INT      NULL,
        INTERNADO                     INT      NULL,
        SINTOMA_FEBRE                 INT      NULL,
        SINTOMA_TOSSE                 INT      NULL,
        SINTOMA_DOR_GARGANTA          INT      NULL,
        SINTOMA_DIFICULDADE_RESPIRAR  INT      NULL,
        SINTOMA_DOR_CABECA            INT      NULL,
        SINTOMA_DOR_PEITO             INT      NULL,
        SINTOMA_NAUSEA                INT      NULL,
        SINTOMA_NARIZ                 INT      NULL,
        SINTOMA_FADIGA                INT      NULL,
        SINTOMA_DOR_OLHOS             INT      NULL,
        SINTOMA_PERDA_CHEIRO_SABOR    INT      NULL,
        SINTOMA_DOR_MUSCULAR          INT      NULL,
        DT_CARGA                      DATETIME NOT NULL CONSTRAINT df_pnad_covid_pessoa_dt_carga DEFAULT (GETDATE()),
        ID_LOG                        INT      NULL
    );

    -- Recarga e leitura do DW sempre filtram por competência (ano/mês).
    CREATE CLUSTERED INDEX ix_pnad_covid_pessoa_competencia
        ON staging.pnad_covid_pessoa (NU_ANO, NU_MES);
END
GO

/* ---------- Linhas rejeitadas ---------- */
IF OBJECT_ID(N'staging.pnad_covid_rejeitado', N'U') IS NULL
BEGIN
    CREATE TABLE staging.pnad_covid_rejeitado
    (
        id_rejeitado  INT IDENTITY(1, 1) NOT NULL,
        id_log        INT                NOT NULL,
        nu_linha      INT                NOT NULL,   -- posição da linha no arquivo
        ds_motivo     VARCHAR(500)       NOT NULL,
        ds_linha      VARCHAR(MAX)       NULL,       -- conteúdo original, para conferência
        dt_carga      DATETIME           NOT NULL CONSTRAINT df_pnad_covid_rejeitado_dt_carga DEFAULT (GETDATE()),
        CONSTRAINT pk_pnad_covid_rejeitado PRIMARY KEY CLUSTERED (id_rejeitado),
        CONSTRAINT fk_pnad_covid_rejeitado_log FOREIGN KEY (id_log) REFERENCES auditoria.log_execucao (id_log)
    );
END
GO

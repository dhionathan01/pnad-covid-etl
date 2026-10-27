/* =============================================================================
   Arquivo  : 04_dw/01_tabelas_dw.sql
   Objetivo : Modelo dimensional (estrela).

                       dim_tempo
                           |
        dim_municipio -- fato_pnad_covid -- dim_pessoa

   Grão da fato: uma linha por mês x município x perfil de pessoa.
   Como a PNAD não traz identificador da pessoa, a dim_pessoa guarda PERFIS
   (combinação única de cor/raça, sexo, faixa etária, escolaridade e faixa de
   rendimento) e a fato soma quantas pessoas de cada perfil responderam.

   Acréscimos em relação ao enunciado (documentados no README):
     dim_tempo.nu_mes ..... número do mês, para ordenar e para achar a chave
     fato.qt_pessoas ...... total de entrevistados no grão, base para percentuais
   ============================================================================= */
USE PNAD_COVID;
GO

/* ---------- dim_tempo ---------- */
IF OBJECT_ID(N'dw.dim_tempo', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_tempo
    (
        sk_tempo  INT IDENTITY(1, 1) NOT NULL,
        nu_ano    INT                NOT NULL,
        nu_mes    INT                NOT NULL,
        no_mes    VARCHAR(20)        NOT NULL,
        CONSTRAINT pk_dim_tempo PRIMARY KEY CLUSTERED (sk_tempo),
        CONSTRAINT uq_dim_tempo_ano_mes UNIQUE (nu_ano, nu_mes),
        CONSTRAINT ck_dim_tempo_mes CHECK (nu_mes BETWEEN 1 AND 12)
    );
END
GO

/* ---------- dim_municipio ---------- */
IF OBJECT_ID(N'dw.dim_municipio', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_municipio
    (
        sk_municipio  INT IDENTITY(1, 1) NOT NULL,
        sg_uf         CHAR(2)            NOT NULL,
        no_municipio  VARCHAR(150)       NOT NULL,
        CONSTRAINT pk_dim_municipio PRIMARY KEY CLUSTERED (sk_municipio),
        CONSTRAINT uq_dim_municipio_uf_nome UNIQUE (sg_uf, no_municipio)
    );
END
GO

/* ---------- dim_pessoa ---------- */
IF OBJECT_ID(N'dw.dim_pessoa', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_pessoa
    (
        sk_pessoa         INT IDENTITY(1, 1) NOT NULL,
        cor_raca          VARCHAR(25)        NOT NULL,
        sexo              CHAR(1)            NOT NULL,
        faixa_etaria      VARCHAR(25)        NOT NULL,
        escolaridade      VARCHAR(50)        NOT NULL,
        faixa_rendimento  VARCHAR(25)        NOT NULL,
        CONSTRAINT pk_dim_pessoa PRIMARY KEY CLUSTERED (sk_pessoa),
        CONSTRAINT uq_dim_pessoa_perfil UNIQUE (cor_raca, sexo, faixa_etaria, escolaridade, faixa_rendimento),
        CONSTRAINT ck_dim_pessoa_sexo CHECK (sexo IN ('M', 'F', 'I'))
    );
END
GO

/* ---------- fato_pnad_covid ---------- */
IF OBJECT_ID(N'dw.fato_pnad_covid', N'U') IS NULL
BEGIN
    CREATE TABLE dw.fato_pnad_covid
    (
        sk_tempo         INT NOT NULL,
        sk_municipio     INT NOT NULL,
        sk_pessoa        INT NOT NULL,
        qt_pessoas       INT NOT NULL,   -- entrevistados no grão
        atendimento_SUS  INT NOT NULL,   -- buscaram pronto socorro do SUS/UPA
        internado        INT NOT NULL,   -- ficaram internados
        sintoma          INT NOT NULL,   -- tiveram ao menos um sintoma de covid
        CONSTRAINT pk_fato_pnad_covid PRIMARY KEY CLUSTERED (sk_tempo, sk_municipio, sk_pessoa),

        -- Integridade referencial garantida pelo próprio banco.
        CONSTRAINT fk_fato_pnad_covid_tempo     FOREIGN KEY (sk_tempo)     REFERENCES dw.dim_tempo (sk_tempo),
        CONSTRAINT fk_fato_pnad_covid_municipio FOREIGN KEY (sk_municipio) REFERENCES dw.dim_municipio (sk_municipio),
        CONSTRAINT fk_fato_pnad_covid_pessoa    FOREIGN KEY (sk_pessoa)    REFERENCES dw.dim_pessoa (sk_pessoa),

        -- Nenhuma métrica pode passar do total de pessoas do grão.
        CONSTRAINT ck_fato_pnad_covid_metricas CHECK (
            atendimento_SUS BETWEEN 0 AND qt_pessoas
            AND internado   BETWEEN 0 AND qt_pessoas
            AND sintoma     BETWEEN 0 AND qt_pessoas)
    );

    CREATE NONCLUSTERED INDEX ix_fato_pnad_covid_municipio ON dw.fato_pnad_covid (sk_municipio);
    CREATE NONCLUSTERED INDEX ix_fato_pnad_covid_pessoa    ON dw.fato_pnad_covid (sk_pessoa);
END
GO

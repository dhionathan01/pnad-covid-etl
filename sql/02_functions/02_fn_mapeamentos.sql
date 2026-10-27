/* =============================================================================
   Arquivo  : 02_functions/02_fn_mapeamentos.sql
   Objetivo : Traduzir os códigos do dicionário do IBGE em descrições.

   Uma function por domínio, todas no schema etl:
     fn_nome_uf, fn_sigla_uf ............ Unidade da Federação
     fn_nome_municipio .................. Município (capitais)
     fn_normalizar_nome_municipio ....... "Município de São Luís (MA)" -> "Sao Luis"
     fn_descricao_sexo, fn_sigla_sexo ... Sexo
     fn_cor_raca ........................ Cor ou raça
     fn_escolaridade .................... Escolaridade
     fn_faixa_etaria .................... Faixa etária (a partir da idade)
     fn_faixa_rendimento ................ Faixa de rendimento
     fn_atendimento_sus ................. Buscou pronto socorro do SUS/UPA
     fn_internado ....................... Internação
     fn_sintoma ......................... Resposta de cada sintoma
     fn_teve_sintoma .................... 1 se teve ao menos um dos 12 sintomas
     fn_nome_mes ........................ Nome do mês

   Código fora do dicionário devolve 'Não informado', para nunca perder a
   linha por causa de um código novo que o IBGE venha a usar.
   ============================================================================= */
USE PNAD_COVID;
GO

/* ---------- 1) Unidade da Federação ---------- */
CREATE OR ALTER FUNCTION etl.fn_nome_uf (@co_uf INT)
RETURNS VARCHAR(30)
AS
BEGIN
    RETURN CASE @co_uf
        WHEN 11 THEN 'Rondônia'            WHEN 12 THEN 'Acre'
        WHEN 13 THEN 'Amazonas'            WHEN 14 THEN 'Roraima'
        WHEN 15 THEN 'Pará'                WHEN 16 THEN 'Amapá'
        WHEN 17 THEN 'Tocantins'           WHEN 21 THEN 'Maranhão'
        WHEN 22 THEN 'Piauí'               WHEN 23 THEN 'Ceará'
        WHEN 24 THEN 'Rio Grande do Norte' WHEN 25 THEN 'Paraíba'
        WHEN 26 THEN 'Pernambuco'          WHEN 27 THEN 'Alagoas'
        WHEN 28 THEN 'Sergipe'             WHEN 29 THEN 'Bahia'
        WHEN 31 THEN 'Minas Gerais'        WHEN 32 THEN 'Espírito Santo'
        WHEN 33 THEN 'Rio de Janeiro'      WHEN 35 THEN 'São Paulo'
        WHEN 41 THEN 'Paraná'              WHEN 42 THEN 'Santa Catarina'
        WHEN 43 THEN 'Rio Grande do Sul'   WHEN 50 THEN 'Mato Grosso do Sul'
        WHEN 51 THEN 'Mato Grosso'         WHEN 52 THEN 'Goiás'
        WHEN 53 THEN 'Distrito Federal'
    END;
END
GO

-- Sigla usada na dim_municipio (sg_uf CHAR(2)). NULL = UF inválida (usado na validação da carga).
CREATE OR ALTER FUNCTION etl.fn_sigla_uf (@co_uf INT)
RETURNS CHAR(2)
AS
BEGIN
    RETURN CASE @co_uf
        WHEN 11 THEN 'RO' WHEN 12 THEN 'AC' WHEN 13 THEN 'AM' WHEN 14 THEN 'RR'
        WHEN 15 THEN 'PA' WHEN 16 THEN 'AP' WHEN 17 THEN 'TO' WHEN 21 THEN 'MA'
        WHEN 22 THEN 'PI' WHEN 23 THEN 'CE' WHEN 24 THEN 'RN' WHEN 25 THEN 'PB'
        WHEN 26 THEN 'PE' WHEN 27 THEN 'AL' WHEN 28 THEN 'SE' WHEN 29 THEN 'BA'
        WHEN 31 THEN 'MG' WHEN 32 THEN 'ES' WHEN 33 THEN 'RJ' WHEN 35 THEN 'SP'
        WHEN 41 THEN 'PR' WHEN 42 THEN 'SC' WHEN 43 THEN 'RS' WHEN 50 THEN 'MS'
        WHEN 51 THEN 'MT' WHEN 52 THEN 'GO' WHEN 53 THEN 'DF'
    END;
END
GO

/* ---------- 2) Municípios ----------
   Na PNAD Covid a coluna CAPITAL traz o código da UF quando a pessoa mora na
   capital, e vem vazia quando mora em outro município. Por isso o mapa é de
   código da UF para nome da capital. */
CREATE OR ALTER FUNCTION etl.fn_nome_municipio (@co_municipio INT)
RETURNS VARCHAR(100)
AS
BEGIN
    RETURN CASE @co_municipio
        WHEN 11 THEN 'Município de Porto Velho (RO)'    WHEN 12 THEN 'Município de Rio Branco (AC)'
        WHEN 13 THEN 'Município de Manaus (AM)'         WHEN 14 THEN 'Município de Boa Vista (RR)'
        WHEN 15 THEN 'Município de Belém (PA)'          WHEN 16 THEN 'Município de Macapá (AP)'
        WHEN 17 THEN 'Município de Palmas (TO)'         WHEN 21 THEN 'Município de São Luís (MA)'
        WHEN 22 THEN 'Município de Teresina (PI)'       WHEN 23 THEN 'Município de Fortaleza (CE)'
        WHEN 24 THEN 'Município de Natal (RN)'          WHEN 25 THEN 'Município de João Pessoa (PB)'
        WHEN 26 THEN 'Município de Recife (PE)'         WHEN 27 THEN 'Município de Maceió (AL)'
        WHEN 28 THEN 'Município de Aracaju (SE)'        WHEN 29 THEN 'Município de Salvador (BA)'
        WHEN 31 THEN 'Município de Belo Horizonte (MG)' WHEN 32 THEN 'Município de Vitória (ES)'
        WHEN 33 THEN 'Município de Rio de Janeiro (RJ)' WHEN 35 THEN 'Município de São Paulo (SP)'
        WHEN 41 THEN 'Município de Curitiba (PR)'       WHEN 42 THEN 'Município de Florianópolis (SC)'
        WHEN 43 THEN 'Município de Porto Alegre (RS)'   WHEN 50 THEN 'Município de Campo Grande (MS)'
        WHEN 51 THEN 'Município de Cuiabá (MT)'         WHEN 52 THEN 'Município de Goiânia (GO)'
        WHEN 53 THEN 'Município de Brasília (DF)'
    END;
END
GO

-- Tira o prefixo "Município de" e o sufixo " (UF)", depois normaliza.
-- Ex.: 'Município de  São Luís (MA)' -> 'Sao Luis'
CREATE OR ALTER FUNCTION etl.fn_normalizar_nome_municipio (@texto NVARCHAR(4000))
RETURNS VARCHAR(150)
AS
BEGIN
    IF @texto IS NULL RETURN NULL;

    DECLARE @nome NVARCHAR(4000) = etl.fn_remover_espacos_extras(@texto);

    -- O banco é accent insensitive, então o LIKE pega "Município" e "Municipio".
    IF @nome LIKE N'Municipio de %'
        SET @nome = SUBSTRING(@nome, CHARINDEX(N' de ', @nome) + 4, 4000);  -- pula " de "

    IF @nome LIKE N'% (__)'
        SET @nome = LEFT(@nome, LEN(@nome) - 5);

    RETURN CAST(etl.fn_normalizar_texto(@nome) AS VARCHAR(150));
END
GO

/* ---------- 3) Sexo ---------- */
CREATE OR ALTER FUNCTION etl.fn_descricao_sexo (@co_sexo INT)
RETURNS VARCHAR(15)
AS
BEGIN
    RETURN CASE @co_sexo WHEN 1 THEN 'Homem' WHEN 2 THEN 'Mulher' ELSE 'Não informado' END;
END
GO

-- Padronização pedida para a dim_pessoa: CHAR(1) com M/F (I = indefinido).
CREATE OR ALTER FUNCTION etl.fn_sigla_sexo (@co_sexo INT)
RETURNS CHAR(1)
AS
BEGIN
    RETURN CASE @co_sexo WHEN 1 THEN 'M' WHEN 2 THEN 'F' ELSE 'I' END;
END
GO

/* ---------- 4) Cor ou raça ---------- */
CREATE OR ALTER FUNCTION etl.fn_cor_raca (@co_cor_raca INT)
RETURNS VARCHAR(25)
AS
BEGIN
    RETURN CASE @co_cor_raca
        WHEN 1 THEN 'Branca'
        WHEN 2 THEN 'Preta'
        WHEN 3 THEN 'Amarela'
        WHEN 4 THEN 'Parda'
        WHEN 5 THEN 'Indígena'
        WHEN 9 THEN 'Ignorado'
        ELSE 'Não informado'
    END;
END
GO

/* ---------- 5) Escolaridade ---------- */
CREATE OR ALTER FUNCTION etl.fn_escolaridade (@co_escolaridade INT)
RETURNS VARCHAR(50)
AS
BEGIN
    RETURN CASE @co_escolaridade
        WHEN 1 THEN 'Sem instrução'
        WHEN 2 THEN 'Fundamental incompleto'
        WHEN 3 THEN 'Fundamental completo'
        WHEN 4 THEN 'Médio incompleto'
        WHEN 5 THEN 'Médio completo'
        WHEN 6 THEN 'Superior incompleto'
        WHEN 7 THEN 'Superior completo'
        WHEN 8 THEN 'Pós-graduação, mestrado ou doutorado'
        ELSE 'Não informado'
    END;
END
GO

/* ---------- 6) Faixa etária ---------- */
CREATE OR ALTER FUNCTION etl.fn_faixa_etaria (@idade INT)
RETURNS VARCHAR(25)
AS
BEGIN
    RETURN CASE
        WHEN @idade IS NULL OR @idade < 0 THEN 'Não informado'
        WHEN @idade <= 17 THEN 'Criança/Adolescente'
        WHEN @idade <= 29 THEN 'Jovem Adulto'
        WHEN @idade <= 59 THEN 'Adulto'
        ELSE 'Idoso'
    END;
END
GO

/* ---------- 7) Faixa de rendimento ----------
   No CSV o código vem como 00, 01, ... e vira 0, 1, ... no INT da staging.
   Vazio significa que a pergunta não se aplica à pessoa. */
CREATE OR ALTER FUNCTION etl.fn_faixa_rendimento (@co_faixa INT)
RETURNS VARCHAR(25)
AS
BEGIN
    RETURN CASE
        WHEN @co_faixa IS NULL THEN 'Não aplicável'
        WHEN @co_faixa = 0 THEN '0 - 100'
        WHEN @co_faixa = 1 THEN '101 - 300'
        WHEN @co_faixa = 2 THEN '301 - 600'
        WHEN @co_faixa = 3 THEN '601 - 800'
        WHEN @co_faixa = 4 THEN '801 - 1.600'
        WHEN @co_faixa = 5 THEN '1.601 - 3.000'
        WHEN @co_faixa = 6 THEN '3.001 - 10.000'
        WHEN @co_faixa = 7 THEN '10.001 - 50.000'
        WHEN @co_faixa = 8 THEN '50.001 - 100.000'
        WHEN @co_faixa = 9 THEN 'Mais de 100.000'
        ELSE 'Não informado'
    END;
END
GO

/* ---------- 8) Atendimento SUS (pronto socorro do SUS/UPA) ---------- */
CREATE OR ALTER FUNCTION etl.fn_atendimento_sus (@codigo INT)
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN CASE
        WHEN @codigo IS NULL THEN 'Não aplicável'
        WHEN @codigo = 1 THEN 'Sim'
        WHEN @codigo = 2 THEN 'Não'
        WHEN @codigo = 9 THEN 'Ignorado'
        ELSE 'Não informado'
    END;
END
GO

/* ---------- 9) Internado ---------- */
CREATE OR ALTER FUNCTION etl.fn_internado (@codigo INT)
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN CASE
        WHEN @codigo IS NULL THEN 'Não aplicável'
        WHEN @codigo = 1 THEN 'Sim'
        WHEN @codigo = 2 THEN 'Não'
        WHEN @codigo = 3 THEN 'Não foi atendido'
        WHEN @codigo = 9 THEN 'Ignorado'
        ELSE 'Não informado'
    END;
END
GO

/* ---------- 10) Sintomas ---------- */
CREATE OR ALTER FUNCTION etl.fn_sintoma (@codigo INT)
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN CASE
        WHEN @codigo IS NULL THEN 'Não aplicável'
        WHEN @codigo = 1 THEN 'Sim'
        WHEN @codigo = 2 THEN 'Não'
        WHEN @codigo = 3 THEN 'Não sabe'
        WHEN @codigo = 9 THEN 'Ignorado'
        ELSE 'Não informado'
    END;
END
GO

-- 1 quando a pessoa respondeu "Sim" (código 1) para pelo menos um dos 12 sintomas.
-- Escrita com um único RETURN para o SQL Server 2019+ conseguir fazer o "inline"
-- da function (ela roda em milhões de linhas na carga da fato).
CREATE OR ALTER FUNCTION etl.fn_teve_sintoma
(
    @febre INT, @tosse INT, @dor_garganta INT, @dificuldade_respirar INT,
    @dor_cabeca INT, @dor_peito INT, @nausea INT, @nariz INT,
    @fadiga INT, @dor_olhos INT, @perda_cheiro_sabor INT, @dor_muscular INT
)
RETURNS INT
AS
BEGIN
    RETURN CASE
        WHEN 1 IN (@febre, @tosse, @dor_garganta, @dificuldade_respirar,
                   @dor_cabeca, @dor_peito, @nausea, @nariz,
                   @fadiga, @dor_olhos, @perda_cheiro_sabor, @dor_muscular)
        THEN 1 ELSE 0
    END;
END
GO

/* ---------- Mês (usado na dim_tempo) ---------- */
CREATE OR ALTER FUNCTION etl.fn_nome_mes (@nu_mes INT)
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN CASE @nu_mes
        WHEN 1  THEN 'Janeiro'  WHEN 2  THEN 'Fevereiro' WHEN 3  THEN 'Março'
        WHEN 4  THEN 'Abril'    WHEN 5  THEN 'Maio'      WHEN 6  THEN 'Junho'
        WHEN 7  THEN 'Julho'    WHEN 8  THEN 'Agosto'    WHEN 9  THEN 'Setembro'
        WHEN 10 THEN 'Outubro'  WHEN 11 THEN 'Novembro'  WHEN 12 THEN 'Dezembro'
    END;
END
GO

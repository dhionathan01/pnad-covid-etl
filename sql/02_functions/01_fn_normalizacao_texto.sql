/* =============================================================================
   Arquivo  : 02_functions/01_fn_normalizacao_texto.sql
   Objetivo : Functions de normalização textual.

     etl.fn_remover_espacos_extras  -> tira espaços das pontas e colapsa espaços repetidos
     etl.fn_remover_acentos         -> troca letras acentuadas pela versão sem acento
     etl.fn_capitular               -> Title Case, mantendo "de, da, do, das, dos, e" em minúsculo
     etl.fn_normalizar_texto        -> aplica as três, nessa ordem

   Por que COLLATE Latin1_General_100_BIN2 dentro das functions?
     O banco é accent insensitive. Numa collation AI, 'á' e 'a' são "iguais",
     então REPLACE/TRANSLATE poderiam casar o caractere errado. A collation
     binária compara byte a byte e deixa o resultado previsível.
   ============================================================================= */
USE PNAD_COVID;
GO

CREATE OR ALTER FUNCTION etl.fn_remover_espacos_extras (@texto NVARCHAR(4000))
RETURNS NVARCHAR(4000)
AS
BEGIN
    IF @texto IS NULL RETURN NULL;

    -- Tab, quebra de linha e retorno de carro viram espaço comum.
    DECLARE @resultado NVARCHAR(4000) =
        REPLACE(REPLACE(REPLACE(@texto, NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' ');

    SET @resultado = LTRIM(RTRIM(@resultado));

    -- Enquanto existir espaço duplo, troca por um só.
    WHILE CHARINDEX(N'  ', @resultado) > 0
        SET @resultado = REPLACE(@resultado, N'  ', N' ');

    RETURN @resultado;
END
GO

CREATE OR ALTER FUNCTION etl.fn_remover_acentos (@texto NVARCHAR(4000))
RETURNS NVARCHAR(4000)
AS
BEGIN
    IF @texto IS NULL RETURN NULL;

    -- TRANSLATE troca cada caractere da 2ª lista pelo da 3ª lista na mesma posição.
    -- As duas listas precisam ter o mesmo tamanho (48 caracteres).
    RETURN TRANSLATE(
        @texto COLLATE Latin1_General_100_BIN2,
        N'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ',
        N'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN'
    );
END
GO

CREATE OR ALTER FUNCTION etl.fn_capitular (@texto NVARCHAR(4000))
RETURNS NVARCHAR(4000)
AS
BEGIN
    IF @texto IS NULL RETURN NULL;

    DECLARE @minusculo      NVARCHAR(4000) = LOWER(@texto),
            @resultado      NVARCHAR(4000) = N'',
            @caractere      NCHAR(1),
            @posicao        INT = 1,
            @tamanho        INT = LEN(@texto),
            @inicio_palavra BIT = 1;

    -- Percorre letra a letra: a primeira letra de cada palavra sobe para maiúscula.
    WHILE @posicao <= @tamanho
    BEGIN
        SET @caractere = SUBSTRING(@minusculo, @posicao, 1);

        SET @resultado += CASE WHEN @inicio_palavra = 1 THEN UPPER(@caractere) ELSE @caractere END;

        -- Espaço, hífen, parêntese, barra e apóstrofo iniciam uma nova palavra.
        SET @inicio_palavra = CASE WHEN @caractere IN (N' ', N'-', N'(', N'/', N'''') THEN 1 ELSE 0 END;

        SET @posicao += 1;
    END

    -- Preposições e conjunção ficam em minúsculo no meio do nome (Rio de Janeiro).
    -- Os espaços nas pontas garantem que só palavras inteiras sejam trocadas.
    SET @resultado = N' ' + @resultado + N' ';
    SET @resultado = REPLACE(@resultado COLLATE Latin1_General_100_BIN2, N' De ',  N' de ');
    SET @resultado = REPLACE(@resultado COLLATE Latin1_General_100_BIN2, N' Da ',  N' da ');
    SET @resultado = REPLACE(@resultado COLLATE Latin1_General_100_BIN2, N' Do ',  N' do ');
    SET @resultado = REPLACE(@resultado COLLATE Latin1_General_100_BIN2, N' Das ', N' das ');
    SET @resultado = REPLACE(@resultado COLLATE Latin1_General_100_BIN2, N' Dos ', N' dos ');
    SET @resultado = REPLACE(@resultado COLLATE Latin1_General_100_BIN2, N' E ',   N' e ');
    SET @resultado = LTRIM(RTRIM(@resultado));

    -- A primeira palavra sempre começa maiúscula, mesmo que seja "de".
    RETURN UPPER(LEFT(@resultado, 1)) + SUBSTRING(@resultado, 2, 4000);
END
GO

CREATE OR ALTER FUNCTION etl.fn_normalizar_texto (@texto NVARCHAR(4000))
RETURNS NVARCHAR(4000)
AS
BEGIN
    RETURN etl.fn_capitular(
               etl.fn_remover_acentos(
                   etl.fn_remover_espacos_extras(@texto)));
END
GO

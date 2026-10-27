/* =============================================================================
   Arquivo  : 02_functions/03_fn_regras_dw.sql
   Objetivo : Regras que combinam outras functions e são usadas em mais de uma
              procedure do DW. Ficam num lugar só para a dimensão e a fato
              calcularem a chave natural exatamente do mesmo jeito.
   ============================================================================= */
USE PNAD_COVID;
GO

-- Nome do município como fica na dw.dim_municipio.
-- Capital: nome normalizado (ex.: 'Sao Luis').
-- Fora da capital (CAPITAL vazio no CSV): 'Demais Municipios' da UF.
CREATE OR ALTER FUNCTION etl.fn_municipio_dw (@co_uf INT, @co_municipio INT)
RETURNS VARCHAR(150)
AS
BEGIN
    RETURN COALESCE(
        etl.fn_normalizar_nome_municipio(etl.fn_nome_municipio(@co_municipio)),
        CAST(etl.fn_normalizar_texto(N'Demais municípios') AS VARCHAR(150))
    );
END
GO

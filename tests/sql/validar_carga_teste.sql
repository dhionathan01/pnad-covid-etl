/* =============================================================================
   Arquivo  : tests/sql/validar_carga_teste.sql
   GERADO por tests/gerar_teste.py. Não edite à mão: altere o gerador.
   Compara o resultado da carga do CSV de teste com os valores esperados.
   ============================================================================= */
USE PNAD_COVID;
SET NOCOUNT ON;

DECLARE @resultado TABLE (verificacao NVARCHAR(200), esperado INT, obtido INT);

INSERT INTO @resultado SELECT N'log usp_carregar: linhas lidas', 19, (SELECT TOP (1) qt_linhas_lidas FROM auditoria.log_execucao WHERE no_processo = 'etl.usp_carregar' ORDER BY id_log DESC);
INSERT INTO @resultado SELECT N'log usp_carregar: linhas gravadas', 12, (SELECT TOP (1) qt_linhas_gravadas FROM auditoria.log_execucao WHERE no_processo = 'etl.usp_carregar' ORDER BY id_log DESC);
INSERT INTO @resultado SELECT N'log usp_carregar: status SUCESSO PARCIAL (1 = sim)', 1, (SELECT TOP (1) CASE WHEN st_execucao = 'SUCESSO PARCIAL' THEN 1 ELSE 0 END FROM auditoria.log_execucao WHERE no_processo = 'etl.usp_carregar' ORDER BY id_log DESC);
INSERT INTO @resultado SELECT N'staging: linhas', 12, (SELECT COUNT(*) FROM staging.pnad_covid_pessoa);
INSERT INTO @resultado SELECT N'staging: faixa de rendimento ''04'' lida como 4', 3, (SELECT COUNT(*) FROM staging.pnad_covid_pessoa WHERE FAIXA_RENDIMENTO = 4);
INSERT INTO @resultado SELECT N'rejeitadas: linhas', 7, (SELECT COUNT(*) FROM staging.pnad_covid_rejeitado);
INSERT INTO @resultado SELECT N'rejeitadas: UF inexistente', 1, (SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%UF inexistente%');
INSERT INTO @resultado SELECT N'rejeitadas: IDADE', 1, (SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%IDADE%');
INSERT INTO @resultado SELECT N'rejeitadas: NU_MES', 1, (SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%NU_MES%');
INSERT INTO @resultado SELECT N'rejeitadas: SEXO', 1, (SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%SEXO%');
INSERT INTO @resultado SELECT N'rejeitadas: CO_MUNICIPIO', 1, (SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%CO_MUNICIPIO%');
INSERT INTO @resultado SELECT N'rejeitadas: não numérico', 1, (SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%numérico%');
INSERT INTO @resultado SELECT N'rejeitadas: mal formada', 1, (SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%mal formada%');
INSERT INTO @resultado SELECT N'dim_tempo: linhas', 2, (SELECT COUNT(*) FROM dw.dim_tempo);
INSERT INTO @resultado SELECT N'dim_tempo: Maio presente', 1, (SELECT COUNT(*) FROM dw.dim_tempo WHERE nu_mes = 5 AND no_mes = 'Maio');
INSERT INTO @resultado SELECT N'dim_municipio: linhas', 8, (SELECT COUNT(*) FROM dw.dim_municipio);
INSERT INTO @resultado SELECT N'dim_municipio: ''Sao Luis'' normalizado (MA)', 1, (SELECT COUNT(*) FROM dw.dim_municipio WHERE sg_uf = 'MA' AND no_municipio COLLATE Latin1_General_100_BIN2 = 'Sao Luis');
INSERT INTO @resultado SELECT N'dim_municipio: ''Rio de Janeiro'' com preposição minúscula', 1, (SELECT COUNT(*) FROM dw.dim_municipio WHERE no_municipio COLLATE Latin1_General_100_BIN2 = 'Rio de Janeiro');
INSERT INTO @resultado SELECT N'dim_municipio: ''Demais Municipios'' de MA e MG', 2, (SELECT COUNT(*) FROM dw.dim_municipio WHERE no_municipio = 'Demais Municipios');
INSERT INTO @resultado SELECT N'dim_pessoa: perfis', 9, (SELECT COUNT(*) FROM dw.dim_pessoa);
INSERT INTO @resultado SELECT N'dim_pessoa: sexo só M/F', 0, (SELECT COUNT(*) FROM dw.dim_pessoa WHERE sexo NOT IN ('M', 'F'));
INSERT INTO @resultado SELECT N'dim_pessoa: renda vazia = ''Não aplicável''', 3, (SELECT COUNT(*) FROM dw.dim_pessoa WHERE faixa_rendimento = 'Não aplicável');
INSERT INTO @resultado SELECT N'fato: linhas (grão)', 11, (SELECT COUNT(*) FROM dw.fato_pnad_covid);
INSERT INTO @resultado SELECT N'fato: pessoas', 12, (SELECT SUM(qt_pessoas) FROM dw.fato_pnad_covid);
INSERT INTO @resultado SELECT N'fato: atendimento_SUS', 4, (SELECT SUM(atendimento_SUS) FROM dw.fato_pnad_covid);
INSERT INTO @resultado SELECT N'fato: internado', 3, (SELECT SUM(internado) FROM dw.fato_pnad_covid);
INSERT INTO @resultado SELECT N'fato: sintoma', 7, (SELECT SUM(sintoma) FROM dw.fato_pnad_covid);
INSERT INTO @resultado SELECT N'log usp_carregar_fato: SUCESSO (1 = sim)', 1, (SELECT TOP (1) CASE WHEN st_execucao = 'SUCESSO' THEN 1 ELSE 0 END FROM auditoria.log_execucao WHERE no_processo = 'etl.usp_carregar_fato' ORDER BY id_log DESC);

SELECT verificacao, esperado, obtido,
       CASE WHEN esperado = obtido THEN 'OK' ELSE 'FALHOU' END AS situacao
FROM @resultado;

IF EXISTS (SELECT 1 FROM @resultado WHERE obtido IS NULL OR obtido <> esperado)
    THROW 50100, N'Teste falhou: veja as linhas com situacao = FALHOU.', 1;

PRINT 'Todas as verificações passaram.';

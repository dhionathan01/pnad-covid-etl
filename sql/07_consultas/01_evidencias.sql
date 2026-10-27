/* =============================================================================
   Arquivo  : 07_consultas/01_evidencias.sql
   Objetivo : Consultas para tirar os prints de cada etapa (docs/evidencias).
              Rode bloco a bloco no SSMS / Azure Data Studio / VS Code.
              A numeração segue o roteiro em docs/evidencias/README.md.
   ============================================================================= */
USE PNAD_COVID;
GO

/* E03. Objetos criados por schema ------------------------------------------- */
SELECT s.name AS schema_nome,
       o.type_desc AS tipo,
       o.name AS objeto
FROM sys.objects AS o
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
WHERE s.name IN ('staging', 'dw', 'etl', 'auditoria')
  AND o.type IN ('U', 'V', 'P', 'FN', 'IF', 'TF')
ORDER BY s.name, o.type_desc, o.name;

/* E04. Functions de normalização funcionando -------------------------------- */
SELECT entrada,
       etl.fn_remover_espacos_extras(entrada) AS sem_espacos_extras,
       etl.fn_remover_acentos(entrada)        AS sem_acentos,
       etl.fn_capitular(entrada)              AS capitular,
       etl.fn_normalizar_texto(entrada)       AS normalizado
FROM (VALUES (N'   são   JOÃO   da  barra '),
             (N'Município de  Florianópolis (SC)'),
             (N'rio de janeiro')) AS t (entrada);

SELECT etl.fn_normalizar_nome_municipio(etl.fn_nome_municipio(c.codigo)) AS municipio_normalizado,
       etl.fn_nome_municipio(c.codigo) AS original
FROM (VALUES (21), (25), (33), (42), (53)) AS c (codigo);

/* E05. Log de execução -------------------------------------------------------- */
SELECT id_log, no_processo, ds_arquivo, dt_inicio, dt_fim,
       DATEDIFF(SECOND, dt_inicio, dt_fim) AS duracao_seg,
       qt_linhas_lidas, qt_linhas_gravadas, st_execucao, ds_observacao
FROM auditoria.log_execucao
ORDER BY id_log DESC;

/* E06. Staging: linhas por competência --------------------------------------- */
SELECT NU_ANO, NU_MES, COUNT(*) AS qt_linhas, MIN(DT_CARGA) AS dt_carga
FROM staging.pnad_covid_pessoa
GROUP BY NU_ANO, NU_MES
ORDER BY NU_ANO, NU_MES;

SELECT TOP (10) * FROM staging.pnad_covid_pessoa;

/* E07. Rejeitadas e motivos --------------------------------------------------- */
SELECT id_log, ds_motivo, COUNT(*) AS qt_linhas
FROM staging.pnad_covid_rejeitado
GROUP BY id_log, ds_motivo
ORDER BY id_log DESC, qt_linhas DESC;

/* E08. Dimensões -------------------------------------------------------------- */
SELECT * FROM dw.dim_tempo ORDER BY nu_ano, nu_mes;
SELECT * FROM dw.dim_municipio ORDER BY sg_uf, no_municipio;
SELECT TOP (20) * FROM dw.dim_pessoa ORDER BY sk_pessoa;

SELECT 'dim_tempo' AS tabela, COUNT(*) AS qt FROM dw.dim_tempo
UNION ALL SELECT 'dim_municipio', COUNT(*) FROM dw.dim_municipio
UNION ALL SELECT 'dim_pessoa', COUNT(*) FROM dw.dim_pessoa
UNION ALL SELECT 'fato_pnad_covid', COUNT(*) FROM dw.fato_pnad_covid;

/* E09. Fato e reconciliação com a staging -------------------------------------
   As duas colunas de cada par precisam bater. */
SELECT st.qt_staging,               ft.qt_fato,
       st.atendimento_sus_staging,  ft.atendimento_sus_fato,
       st.internado_staging,        ft.internado_fato
FROM (SELECT COUNT(*) AS qt_staging,
             SUM(CASE WHEN ATENDIMENTO_SUS = 1 THEN 1 ELSE 0 END) AS atendimento_sus_staging,
             SUM(CASE WHEN INTERNADO = 1 THEN 1 ELSE 0 END) AS internado_staging
      FROM staging.pnad_covid_pessoa) AS st
CROSS JOIN
     (SELECT SUM(qt_pessoas) AS qt_fato,
             SUM(atendimento_SUS) AS atendimento_sus_fato,
             SUM(internado) AS internado_fato
      FROM dw.fato_pnad_covid) AS ft;

/* E10. Integridade referencial (todas devem retornar 0) ---------------------- */
SELECT
    (SELECT COUNT(*) FROM dw.fato_pnad_covid f
      WHERE NOT EXISTS (SELECT 1 FROM dw.dim_tempo d WHERE d.sk_tempo = f.sk_tempo))           AS orfaos_tempo,
    (SELECT COUNT(*) FROM dw.fato_pnad_covid f
      WHERE NOT EXISTS (SELECT 1 FROM dw.dim_municipio d WHERE d.sk_municipio = f.sk_municipio)) AS orfaos_municipio,
    (SELECT COUNT(*) FROM dw.fato_pnad_covid f
      WHERE NOT EXISTS (SELECT 1 FROM dw.dim_pessoa d WHERE d.sk_pessoa = f.sk_pessoa))         AS orfaos_pessoa;

SELECT fk.name AS foreign_key, OBJECT_NAME(fk.referenced_object_id) AS referencia, fk.is_disabled
FROM sys.foreign_keys fk
WHERE fk.parent_object_id = OBJECT_ID(N'dw.fato_pnad_covid');

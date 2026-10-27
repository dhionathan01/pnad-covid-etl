/* =============================================================================
   Arquivo  : 07_consultas/02_analises.sql
   Objetivo : Exemplos de perguntas que o DW responde.

   Observação: a PNAD é amostral. Estas contagens são de ENTREVISTADOS, sem o
   peso amostral (V1032), então mostram a amostra e não a população do Brasil.
   ============================================================================= */
USE PNAD_COVID;
GO

/* 1. Evolução mensal: % com sintoma, % que buscou SUS, % internado ----------- */
SELECT t.nu_ano, t.nu_mes, t.no_mes,
       SUM(f.qt_pessoas) AS entrevistados,
       CAST(100.0 * SUM(f.sintoma)         / SUM(f.qt_pessoas) AS DECIMAL(5, 2)) AS pct_sintoma,
       CAST(100.0 * SUM(f.atendimento_SUS) / SUM(f.qt_pessoas) AS DECIMAL(5, 2)) AS pct_sus,
       CAST(100.0 * SUM(f.internado)       / SUM(f.qt_pessoas) AS DECIMAL(5, 2)) AS pct_internado
FROM dw.fato_pnad_covid f
JOIN dw.dim_tempo t ON t.sk_tempo = f.sk_tempo
GROUP BY t.nu_ano, t.nu_mes, t.no_mes
ORDER BY t.nu_ano, t.nu_mes;

/* 2. Capitais com maior proporção de entrevistados com sintoma ---------------- */
SELECT TOP (10)
       m.sg_uf, m.no_municipio,
       SUM(f.qt_pessoas) AS entrevistados,
       CAST(100.0 * SUM(f.sintoma) / SUM(f.qt_pessoas) AS DECIMAL(5, 2)) AS pct_sintoma
FROM dw.fato_pnad_covid f
JOIN dw.dim_municipio m ON m.sk_municipio = f.sk_municipio
WHERE m.no_municipio <> 'Demais Municipios'
GROUP BY m.sg_uf, m.no_municipio
ORDER BY pct_sintoma DESC;

/* 3. Busca pelo SUS por faixa de rendimento ---------------------------------- */
SELECT p.faixa_rendimento,
       SUM(f.sintoma) AS com_sintoma,
       SUM(f.atendimento_SUS) AS buscaram_sus,
       CAST(100.0 * SUM(f.atendimento_SUS) / NULLIF(SUM(f.sintoma), 0) AS DECIMAL(5, 2)) AS pct_sus_entre_sintomaticos
FROM dw.fato_pnad_covid f
JOIN dw.dim_pessoa p ON p.sk_pessoa = f.sk_pessoa
GROUP BY p.faixa_rendimento
ORDER BY p.faixa_rendimento;

/* 4. Internações por faixa etária e sexo ------------------------------------- */
SELECT p.faixa_etaria, p.sexo,
       SUM(f.internado) AS internados,
       SUM(f.qt_pessoas) AS entrevistados
FROM dw.fato_pnad_covid f
JOIN dw.dim_pessoa p ON p.sk_pessoa = f.sk_pessoa
GROUP BY p.faixa_etaria, p.sexo
ORDER BY p.faixa_etaria, p.sexo;

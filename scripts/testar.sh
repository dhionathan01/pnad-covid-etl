#!/usr/bin/env bash
# Teste de ponta a ponta com o CSV pequeno de tests/dados.
# ATENÇÃO: limpa staging, dimensões e fato antes (o log é mantido).
# Depois do teste, rode executar_pipeline.sh para carregar os dados reais de novo.
# Uso: ./scripts/testar.sh

source "$(dirname "$0")/_comum.sh"

aguardar_sqlserver

echo ">> Limpando staging, dimensões e fato"
sql -d PNAD_COVID -Q "EXEC etl.usp_limpar_carga;"

echo ">> Carregando CSV de teste"
sql -d PNAD_COVID -Q "EXEC etl.usp_carregar @caminho_arquivo = N'/var/opt/mssql/dados_teste/PNAD_COVID_TESTE.csv';"

echo ">> Carregando dimensões e fato"
sql -d PNAD_COVID -Q "EXEC etl.usp_executar_pipeline;"

echo ">> Validando resultados"
sql -d PNAD_COVID -i /sql_testes/validar_carga_teste.sql

echo
echo "Todos os testes passaram."

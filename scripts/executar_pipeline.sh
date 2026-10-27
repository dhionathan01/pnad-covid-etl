#!/usr/bin/env bash
# Executa o ETL completo:
#   1. etl.usp_carregar para cada CSV de dados/ (CSV -> staging)
#   2. etl.usp_executar_pipeline (dimensões e fato)
#   3. Mostra o log da execução
# Uso: ./scripts/executar_pipeline.sh

source "$(dirname "$0")/_comum.sh"

aguardar_sqlserver

shopt -s nullglob
CSVS=("$RAIZ"/dados/*.csv)
if [[ ${#CSVS[@]} -eq 0 ]]; then
  echo "Nenhum CSV em dados/. Rode antes: ./scripts/baixar_dados.sh" >&2
  exit 1
fi

for csv in "${CSVS[@]}"; do
  nome="$(basename "$csv")"
  echo ">> Carregando $nome na staging"
  # Não para no primeiro arquivo com erro: o log registra e o próximo arquivo segue.
  sql -d PNAD_COVID -Q "EXEC etl.usp_carregar @caminho_arquivo = N'/var/opt/mssql/dados/$nome';" \
    || echo "   Falha em $nome (detalhes em auditoria.log_execucao)"
done

echo ">> Carregando dimensões e fato"
sql -d PNAD_COVID -Q "EXEC etl.usp_executar_pipeline;"

echo
echo ">> Log das últimas execuções"
sql -d PNAD_COVID -W -s " | " -Q "SET NOCOUNT ON; SELECT TOP (20) id_log, no_processo, dt_inicio, dt_fim, qt_linhas_lidas, qt_linhas_gravadas, st_execucao, LEFT(ds_observacao, 120) AS ds_observacao FROM auditoria.log_execucao ORDER BY id_log DESC;"

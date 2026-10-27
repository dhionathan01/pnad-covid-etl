#!/usr/bin/env bash
# Baixa os microdados da PNAD Covid-19 do FTP do IBGE e extrai os CSVs em dados/.
# Uso:
#   ./scripts/baixar_dados.sh            # todos os meses (05 a 11 de 2020)
#   ./scripts/baixar_dados.sh 05 06      # só os meses informados

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="$RAIZ/dados"
URL_BASE="https://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_PNAD_COVID19/Microdados/Dados"

if [[ $# -gt 0 ]]; then
  MESES=("$@")
else
  MESES=(05 06 07 08 09 10 11)
fi

command -v unzip >/dev/null || { echo "Instale o unzip (ex.: sudo apt install unzip)." >&2; exit 1; }

mkdir -p "$DESTINO"

for mes in "${MESES[@]}"; do
  arquivo="PNAD_COVID_${mes}2020.zip"
  echo "Baixando $arquivo..."
  curl -fL --retry 3 -o "$DESTINO/$arquivo" "$URL_BASE/$arquivo"

  # -j descarta pastas internas do zip, -o sobrescreve sem perguntar
  unzip -o -j "$DESTINO/$arquivo" '*.csv' -d "$DESTINO"
  rm -f "$DESTINO/$arquivo"
done

echo
echo "CSVs disponíveis em dados/:"
ls -lh "$DESTINO"/*.csv

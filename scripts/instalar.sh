#!/usr/bin/env bash
# Cria (ou atualiza) banco, schemas, tabelas, functions e procedures.
# Os scripts são idempotentes: pode rodar quantas vezes quiser.
# Uso: ./scripts/instalar.sh

source "$(dirname "$0")/_comum.sh"

aguardar_sqlserver

# Ordem garantida pelo prefixo numérico das pastas e arquivos.
# A pasta 07_consultas fica de fora: são consultas de evidência, rodadas à mão.
mapfile -t ARQUIVOS < <(cd "$RAIZ/sql" && find . -name '*.sql' -not -path './07_consultas/*' | sort)

for arquivo in "${ARQUIVOS[@]}"; do
  caminho="/sql/${arquivo#./}"
  echo ">> $caminho"
  sql -i "$caminho"
done

echo
echo "Instalação concluída."

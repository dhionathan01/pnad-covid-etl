#!/usr/bin/env bash
# Funções compartilhadas pelos scripts .sh
# Carregado com: source "$(dirname "$0")/_comum.sh"

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="pnad-sqlserver"
SQLCMD="/opt/mssql-tools18/bin/sqlcmd"

# Lê o .env (senha e porta). Sem .env, para com uma mensagem clara.
if [[ ! -f "$RAIZ/.env" ]]; then
  echo "Arquivo .env não encontrado. Rode: cp .env.example .env" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
source "$RAIZ/.env"
set +a

# Executa sqlcmd dentro do container.
#   -C  confia no certificado autoassinado do container
#   -b  sai com erro quando o SQL falha (o script para)
#   -I  QUOTED_IDENTIFIER ON (o padrão do sqlcmd é OFF)
#   -f 65001  lê e escreve em UTF-8 (acentos dos scripts)
# A senha vai por variável de ambiente para não aparecer na lista de processos.
sql() {
  docker exec -i -e SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" "$CONTAINER" \
    "$SQLCMD" -S localhost -U sa -C -b -I -f 65001 "$@"
}

# Espera o container ficar saudável (healthcheck do docker-compose).
aguardar_sqlserver() {
  echo "Aguardando o SQL Server ficar pronto..."
  for _ in $(seq 1 60); do
    estado="$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo "ausente")"
    if [[ "$estado" == "healthy" ]]; then
      echo "SQL Server pronto."
      return 0
    fi
    sleep 3
  done
  echo "O container $CONTAINER não ficou saudável. Veja: docker compose logs sqlserver" >&2
  exit 1
}

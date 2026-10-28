#!/usr/bin/env bash
# Cria o ambiente virtual do notebook em .venv/ e registra o kernel no Jupyter.
# Uso: ./scripts/criar_venv.sh        (precisa de Python 3.10 ou mais novo)

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

PYTHON="${PYTHON:-python3}"
"$PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' \
  || { echo "É preciso Python 3.10 ou mais novo." >&2; exit 1; }

echo ">> Criando .venv"
"$PYTHON" -m venv .venv

echo ">> Instalando dependências"
.venv/bin/python -m pip install --upgrade pip --quiet
.venv/bin/python -m pip install -r notebooks/requirements.txt --quiet

echo ">> Registrando o kernel 'PNAD Covid (venv)'"
.venv/bin/python -m ipykernel install --user --name pnad-covid --display-name "PNAD Covid (venv)"

echo
echo "Pronto. Para abrir o notebook:"
echo "  source .venv/bin/activate"
echo "  jupyter lab notebooks/pnad_covid_etl.ipynb"
echo "No VS Code, abra o .ipynb e escolha o kernel 'PNAD Covid (venv)'."

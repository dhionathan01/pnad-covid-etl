#!/usr/bin/env bash
# Cria o ambiente virtual do notebook em .venv/ e registra o kernel no Jupyter.
# Uso: ./scripts/criar_venv.sh        (precisa de Python 3.10 ou mais novo)

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

# No Windows (Git Bash) o Python costuma se chamar "python" ou "py", não "python3".
versao_ok='import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)'
if [[ -z "${PYTHON:-}" ]]; then
  for candidato in python3 python py; do
    if command -v "$candidato" >/dev/null 2>&1 && "$candidato" -c "$versao_ok" 2>/dev/null; then
      PYTHON="$candidato"
      break
    fi
  done
fi
[[ -n "${PYTHON:-}" ]] && "$PYTHON" -c "$versao_ok" \
  || { echo "É preciso Python 3.10 ou mais novo." >&2; exit 1; }

echo ">> Criando .venv"
"$PYTHON" -m venv .venv

# O venv do Windows usa Scripts/ no lugar de bin/.
if [[ -d .venv/Scripts ]]; then
  BIN=".venv/Scripts"
else
  BIN=".venv/bin"
fi

echo ">> Instalando dependências"
"$BIN/python" -m pip install --upgrade pip --quiet
"$BIN/python" -m pip install -r notebooks/requirements.txt --quiet

echo ">> Registrando o kernel 'PNAD Covid (venv)'"
"$BIN/python" -m ipykernel install --user --name pnad-covid --display-name "PNAD Covid (venv)"

echo
echo "Pronto. Para abrir o notebook:"
echo "  source $BIN/activate"
echo "  jupyter lab pnad_covid_etl.ipynb"
echo "No VS Code: feche e abra o VS Code de novo (ou Ctrl+Shift+P > Developer: Reload Window),"
echo "abra pnad_covid_etl.ipynb e escolha o kernel 'PNAD Covid (venv)'."

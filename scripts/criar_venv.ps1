# Cria o ambiente virtual do notebook em .venv\ e registra o kernel no Jupyter.
# Uso: .\scripts\criar_venv.ps1        (precisa de Python 3.10 ou mais novo)

$ErrorActionPreference = 'Stop'
$Raiz = Split-Path -Parent $PSScriptRoot
Set-Location $Raiz

# "py" é o lançador oficial do Python no Windows; cai para "python" se não existir.
$python = if (Get-Command py -ErrorAction SilentlyContinue) { 'py' } else { 'python' }
& $python -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)"
if ($LASTEXITCODE -ne 0) { throw 'É preciso Python 3.10 ou mais novo.' }

Write-Host '>> Criando .venv'
& $python -m venv .venv

$venvPython = Join-Path $Raiz '.venv\Scripts\python.exe'

Write-Host '>> Instalando dependências'
& $venvPython -m pip install --upgrade pip --quiet
& $venvPython -m pip install -r notebooks\requirements.txt --quiet
if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar as dependências.' }

Write-Host ">> Registrando o kernel 'PNAD Covid (venv)'"
& $venvPython -m ipykernel install --user --name pnad-covid --display-name 'PNAD Covid (venv)'

Write-Host ''
Write-Host 'Pronto. Para abrir o notebook:'
Write-Host '  .\.venv\Scripts\Activate.ps1'
Write-Host '  jupyter lab notebooks\pnad_covid_etl.ipynb'
Write-Host "No VS Code, abra o .ipynb e escolha o kernel 'PNAD Covid (venv)'."

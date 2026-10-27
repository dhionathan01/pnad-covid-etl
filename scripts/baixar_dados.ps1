# Baixa os microdados da PNAD Covid-19 do FTP do IBGE e extrai os CSVs em dados\.
# Uso:
#   .\scripts\baixar_dados.ps1                  # todos os meses (05 a 11 de 2020)
#   .\scripts\baixar_dados.ps1 -Meses 05,06     # só os meses informados

param([string[]]$Meses = @('05', '06', '07', '08', '09', '10', '11'))

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # deixa o Invoke-WebRequest bem mais rápido

$Raiz    = Split-Path -Parent $PSScriptRoot
$Destino = Join-Path $Raiz 'dados'
$UrlBase = 'https://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_PNAD_COVID19/Microdados/Dados'

New-Item -ItemType Directory -Force -Path $Destino | Out-Null

foreach ($mes in $Meses) {
    $arquivo = "PNAD_COVID_${mes}2020.zip"
    $zip     = Join-Path $Destino $arquivo
    Write-Host "Baixando $arquivo..."
    Invoke-WebRequest -Uri "$UrlBase/$arquivo" -OutFile $zip

    # Extrai numa pasta temporária e move só os CSVs para dados\
    $temp = Join-Path $Destino "_tmp_$mes"
    Expand-Archive -Path $zip -DestinationPath $temp -Force
    Get-ChildItem $temp -Recurse -Filter '*.csv' | Move-Item -Destination $Destino -Force
    Remove-Item $temp -Recurse -Force
    Remove-Item $zip -Force
}

Write-Host ''
Write-Host 'CSVs disponíveis em dados\:'
Get-ChildItem $Destino -Filter '*.csv' | Format-Table Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }

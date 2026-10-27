# Cria (ou atualiza) banco, schemas, tabelas, functions e procedures.
# Uso: .\scripts\instalar.ps1

. "$PSScriptRoot\_comum.ps1"

Wait-SqlServer

$pastaSql = Join-Path $Raiz 'sql'
$arquivos = Get-ChildItem $pastaSql -Recurse -Filter '*.sql' |
    Where-Object { $_.FullName -notmatch '07_consultas' } |
    ForEach-Object { $_.FullName.Substring($pastaSql.Length + 1).Replace('\', '/') } |
    Sort-Object

foreach ($relativo in $arquivos) {
    Write-Host ">> /sql/$relativo"
    Invoke-Sql -i "/sql/$relativo"
}

Write-Host ''
Write-Host 'Instalação concluída.'

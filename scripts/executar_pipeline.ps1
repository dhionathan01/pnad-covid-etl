# Executa o ETL completo (CSV -> staging -> dimensões -> fato) e mostra o log.
# Uso: .\scripts\executar_pipeline.ps1

. "$PSScriptRoot\_comum.ps1"

Wait-SqlServer

$csvs = Get-ChildItem (Join-Path $Raiz 'dados') -Filter '*.csv'
if (-not $csvs) { throw 'Nenhum CSV em dados\. Rode antes: .\scripts\baixar_dados.ps1' }

foreach ($csv in $csvs) {
    Write-Host ">> Carregando $($csv.Name) na staging"
    try {
        Invoke-Sql -d PNAD_COVID -Q "EXEC etl.usp_carregar @caminho_arquivo = N'/var/opt/mssql/dados/$($csv.Name)';"
    } catch {
        Write-Warning "Falha em $($csv.Name) (detalhes em auditoria.log_execucao)"
    }
}

Write-Host '>> Carregando dimensões e fato'
Invoke-Sql -d PNAD_COVID -Q 'EXEC etl.usp_executar_pipeline;'

Write-Host ''
Write-Host '>> Log das últimas execuções'
Invoke-Sql -d PNAD_COVID -W -s ' | ' -Q 'SET NOCOUNT ON; SELECT TOP (20) id_log, no_processo, dt_inicio, dt_fim, qt_linhas_lidas, qt_linhas_gravadas, st_execucao, LEFT(ds_observacao, 120) AS ds_observacao FROM auditoria.log_execucao ORDER BY id_log DESC;'

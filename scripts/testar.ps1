# Teste de ponta a ponta com o CSV pequeno de tests\dados.
# ATENÇÃO: limpa staging, dimensões e fato antes (o log é mantido).
# Uso: .\scripts\testar.ps1

. "$PSScriptRoot\_comum.ps1"

Wait-SqlServer

Write-Host '>> Limpando staging, dimensões e fato'
Invoke-Sql -d PNAD_COVID -Q 'EXEC etl.usp_limpar_carga;'

Write-Host '>> Carregando CSV de teste'
Invoke-Sql -d PNAD_COVID -Q "EXEC etl.usp_carregar @caminho_arquivo = N'/var/opt/mssql/dados_teste/PNAD_COVID_TESTE.csv';"

Write-Host '>> Carregando dimensões e fato'
Invoke-Sql -d PNAD_COVID -Q 'EXEC etl.usp_executar_pipeline;'

Write-Host '>> Validando resultados'
Invoke-Sql -d PNAD_COVID -i /sql_testes/validar_carga_teste.sql

Write-Host ''
Write-Host 'Todos os testes passaram.'

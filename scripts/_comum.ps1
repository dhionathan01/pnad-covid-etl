# Funções compartilhadas pelos scripts .ps1
# Carregado com: . "$PSScriptRoot\_comum.ps1"

$ErrorActionPreference = 'Stop'

$Raiz      = Split-Path -Parent $PSScriptRoot
$Container = 'pnad-sqlserver'
$Sqlcmd    = '/opt/mssql-tools18/bin/sqlcmd'

# Lê o .env (senha e porta).
$ArquivoEnv = Join-Path $Raiz '.env'
if (-not (Test-Path $ArquivoEnv)) {
    throw 'Arquivo .env não encontrado. Rode: Copy-Item .env.example .env'
}
Get-Content $ArquivoEnv | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
    $nome, $valor = $_ -split '=', 2
    Set-Item -Path "Env:$($nome.Trim())" -Value $valor.Trim()
}

# Executa sqlcmd dentro do container (mesmas flags do _comum.sh).
# Função simples (sem param) de propósito: assim $args recebe "-d", "-Q" etc. como texto
# e repassa tudo ao sqlcmd, em vez de o PowerShell tentar interpretar como parâmetros.
function Invoke-Sql {
    docker exec -i -e "SQLCMDPASSWORD=$env:MSSQL_SA_PASSWORD" $Container `
        $Sqlcmd -S localhost -U sa -C -b -I -f 65001 @args
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd terminou com erro ($LASTEXITCODE)." }
}

function Wait-SqlServer {
    Write-Host 'Aguardando o SQL Server ficar pronto...'
    for ($i = 0; $i -lt 60; $i++) {
        $estado = docker inspect -f '{{.State.Health.Status}}' $Container 2>$null
        if ($estado -eq 'healthy') { Write-Host 'SQL Server pronto.'; return }
        Start-Sleep -Seconds 3
    }
    throw "O container $Container não ficou saudável. Veja: docker compose logs sqlserver"
}

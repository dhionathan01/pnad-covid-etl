# dados/

Pasta onde ficam os CSVs da PNAD Covid-19 baixados do IBGE. Ela é montada dentro do container em `/var/opt/mssql/dados`, que é o caminho que o `BULK INSERT` usa.

Para preencher:

```bash
./scripts/baixar_dados.sh          # Linux / macOS / Git Bash
.\scripts\baixar_dados.ps1         # Windows PowerShell
```

Os arquivos não vão para o git (ver `.gitignore`).

Fonte: https://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_PNAD_COVID19/Microdados/Dados/

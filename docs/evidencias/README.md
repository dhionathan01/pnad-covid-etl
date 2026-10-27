# Roteiro de evidências

Um print por item, salvo nesta pasta com o código no nome (ex.: `E05_log_execucao.png`).
As consultas de E03 a E10 estão em `sql/07_consultas/01_evidencias.sql`, com os mesmos códigos.

| Código | Etapa | O que mostrar |
|--------|-------|---------------|
| E01 | Ambiente | `docker compose ps` com o container `pnad-sqlserver` healthy |
| E02 | Instalação | Saída de `scripts/instalar` com os 15 scripts executados |
| E03 | Objetos | Tabelas, views, functions e procedures por schema |
| E04 | Functions | Antes e depois das functions de normalização |
| E05 | Log | `auditoria.log_execucao` com lidas, gravadas, status e observação de cada etapa |
| E06 | Staging | Linhas por competência e amostra de `staging.pnad_covid_pessoa` |
| E07 | Rejeitadas | Motivos e quantidades em `staging.pnad_covid_rejeitado` |
| E08 | Dimensões | Conteúdo de `dim_tempo`, `dim_municipio`, amostra de `dim_pessoa` e contagens |
| E09 | Fato | Reconciliação: totais da fato iguais aos da staging |
| E10 | Integridade | Órfãos zerados e FKs da fato ativas |
| E11 | Teste | Saída de `scripts/testar` com as 28 verificações OK |

Dica: rode o teste (E11) antes da carga real. Ele limpa staging, dimensões e fato, então os prints E05 a E10 ficam melhores depois do `executar_pipeline`, com os dados reais.

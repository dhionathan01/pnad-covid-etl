"""
Gera o CSV de teste e o script de validação a partir dos mesmos dados.

    python tests/gerar_teste.py

Saídas
    tests/dados/PNAD_COVID_TESTE.csv    -> arquivo no layout do IBGE (com colunas extras e linhas inválidas)
    tests/sql/validar_carga_teste.sql   -> asserts que o testar.sh/.ps1 executa depois da carga

O CSV imita o arquivo real de propósito:
    - cabeçalho entre aspas, valores sem aspas (e uma linha toda entre aspas)
    - colunas extras entre as que usamos, para provar que a leitura é por nome
    - quebra de linha do Windows (CRLF)
    - linhas inválidas, uma para cada regra de validação
"""

from pathlib import Path

RAIZ = Path(__file__).resolve().parent

# Cabeçalho no estilo do IBGE (subconjunto). A ordem não importa para a carga.
SINTOMAS = ["B0011", "B0012", "B0013", "B0014", "B0015", "B0016",
            "B0017", "B0018", "B0019", "B00110", "B00111", "B00112"]
CABECALHO = (
    ["Ano", "UF", "CAPITAL", "RM_RIDE", "V1008", "V1012", "V1013", "V1016",
     "Estrato", "UPA", "V1022", "V1023", "V1030", "V1031", "V1032", "posest",
     "A001", "A001A", "A002", "A003", "A004", "A005", "A006"]
    + SINTOMAS
    + ["B00113", "B002", "B0041", "B0042", "B0043", "B005", "B006",
       "C001", "C002", "C007", "C01011", "C01012"]
)

FEBRE, TOSSE, GARGANTA, RESPIRAR, CABECA, PEITO, NAUSEA, NARIZ, FADIGA, OLHOS, CHEIRO, MUSCULAR = range(12)


def sintomas(*indices_sim, vazio=False):
    """12 respostas: 1 (Sim) nos índices informados, 2 (Não) nos demais."""
    if vazio:
        return [None] * 12
    return [1 if i in indices_sim else 2 for i in range(12)]


# Linhas válidas: (mes, uf, capital, idade, sexo, cor, escolaridade, renda, sus, internado, sintomas, entre_aspas)
VALIDAS = [
    (5, 21, 21,   34, 2, 4, 5, 4,    1,    2,    sintomas(FEBRE),           False),
    (5, 21, None, 70, 1, 1, 2, None, None, None, sintomas(),                False),
    (5, 33, 33,   15, 1, 2, 2, None, 2,    None, sintomas(TOSSE),           False),
    (5, 33, 33,   45, 2, 1, 7, 6,    1,    1,    sintomas(FEBRE, MUSCULAR), False),
    (5, 35, 35,   22, 1, 4, 6, 3,    None, None, sintomas(),                False),
    (5, 42, 42,   61, 2, 1, 8, 5,    2,    3,    sintomas(NARIZ),           False),
    (6, 21, 21,   34, 2, 4, 5, 4,    2,    2,    sintomas(),                False),
    (6, 21, 21,   38, 2, 4, 5, 4,    1,    1,    sintomas(CHEIRO),          False),
    (6, 53, 53,   29, 1, 5, 3, 0,    None, None, sintomas(vazio=True),      False),
    (6, 31, None, 50, 2, 9, 4, 9,    2,    None, sintomas(),                False),
    (6, 25, 25,   80, 1, 3, 1, None, 1,    1,    sintomas(RESPIRAR),        False),
    (6, 35, 35,   22, 1, 4, 6, 3,    None, None, sintomas(CABECA),          True),
]


def montar_linha(mes, uf, capital, idade, sexo, cor, esc, renda, sus, internado, sint, aspas=False, ano=2020):
    valores = {
        "Ano": ano, "UF": uf, "CAPITAL": capital, "RM_RIDE": None, "V1008": 1, "V1012": 2,
        "V1013": mes, "V1016": 1, "Estrato": 1110011, "UPA": 110015970, "V1022": 1, "V1023": 1,
        "V1030": 152539, "V1031": "38.43", "V1032": "70.12", "posest": 111,
        "A001": 1, "A001A": 1, "A002": idade, "A003": sexo, "A004": cor, "A005": esc, "A006": None,
        "B00113": 2, "B002": None, "B0041": None, "B0042": sus, "B0043": None, "B005": internado,
        "B006": None, "C001": 1, "C002": None, "C007": 2,
        "C01011": None if renda is None else f"{renda:02d}", "C01012": None,
    }
    for coluna, resposta in zip(SINTOMAS, sint):
        valores[coluna] = resposta

    def fmt(v):
        texto = "" if v is None else str(v)
        return f'"{texto}"' if aspas else texto

    return ",".join(fmt(valores[c]) for c in CABECALHO)


def linha_valida(t):
    mes, uf, cap, idade, sexo, cor, esc, renda, sus, intern, sint, aspas = t
    return montar_linha(mes, uf, cap, idade, sexo, cor, esc, renda, sus, intern, sint, aspas)


def substituir(linha, coluna, novo):
    partes = linha.split(",")
    partes[CABECALHO.index(coluna)] = novo
    return ",".join(partes)


base = montar_linha(6, 31, 31, 40, 1, 1, 5, 4, 2, None, sintomas())

# Uma linha inválida para cada regra (motivo esperado no comentário).
INVALIDAS = [
    montar_linha(6, 99, None, 40, 1, 1, 5, 4, 2, None, sintomas()),      # UF inexistente
    substituir(base, "A002", ""),                                         # IDADE ausente
    substituir(base, "V1013", "13"),                                      # NU_MES fora de 1 a 12
    substituir(base, "A003", "3"),                                        # SEXO diferente de 1 ou 2
    substituir(base, "CAPITAL", "35"),                                    # CO_MUNICIPIO não é a capital da UF
    substituir(base, "B0011", "X"),                                       # código não numérico
    substituir(base, "C002", "\\x"),                                      # barra invertida: JSON inválido -> mal formada
]

# ---------------------------------------------------------------- CSV
linhas = [",".join(f'"{c}"' for c in CABECALHO)]
linhas += [linha_valida(t) for t in VALIDAS]
linhas.insert(4, INVALIDAS[0])          # inválidas espalhadas no meio do arquivo
linhas.insert(8, INVALIDAS[1])
linhas += INVALIDAS[2:]
linhas.append("")                       # linha em branco no fim (deve ser ignorada)

csv_path = RAIZ / "dados" / "PNAD_COVID_TESTE.csv"
csv_path.parent.mkdir(parents=True, exist_ok=True)
csv_path.write_bytes(("\r\n".join(linhas)).encode("ascii"))

# ---------------------------------------------------------------- Esperados


def faixa_etaria(idade):
    if idade <= 17:
        return "Criança/Adolescente"
    if idade <= 29:
        return "Jovem Adulto"
    if idade <= 59:
        return "Adulto"
    return "Idoso"


qt_lidas = len(VALIDAS) + len(INVALIDAS)
qt_gravadas = len(VALIDAS)
competencias = {t[0] for t in VALIDAS}
municipios = {(t[1], t[2]) for t in VALIDAS}
perfis = {(t[5], t[4], faixa_etaria(t[3]), t[6], t[7]) for t in VALIDAS}
graos = {(t[0], t[1], t[2], (t[5], t[4], faixa_etaria(t[3]), t[6], t[7])) for t in VALIDAS}
qt_sus = sum(1 for t in VALIDAS if t[8] == 1)
qt_internado = sum(1 for t in VALIDAS if t[9] == 1)
qt_sintoma = sum(1 for t in VALIDAS if 1 in t[10])

ESPERADOS = [
    ("log usp_carregar: linhas lidas",
     "SELECT TOP (1) qt_linhas_lidas FROM auditoria.log_execucao WHERE no_processo = 'etl.usp_carregar' ORDER BY id_log DESC",
     qt_lidas),
    ("log usp_carregar: linhas gravadas",
     "SELECT TOP (1) qt_linhas_gravadas FROM auditoria.log_execucao WHERE no_processo = 'etl.usp_carregar' ORDER BY id_log DESC",
     qt_gravadas),
    ("log usp_carregar: status SUCESSO PARCIAL (1 = sim)",
     "SELECT TOP (1) CASE WHEN st_execucao = 'SUCESSO PARCIAL' THEN 1 ELSE 0 END FROM auditoria.log_execucao WHERE no_processo = 'etl.usp_carregar' ORDER BY id_log DESC",
     1),
    ("staging: linhas", "SELECT COUNT(*) FROM staging.pnad_covid_pessoa", qt_gravadas),
    ("staging: faixa de rendimento '04' lida como 4",
     "SELECT COUNT(*) FROM staging.pnad_covid_pessoa WHERE FAIXA_RENDIMENTO = 4",
     sum(1 for t in VALIDAS if t[7] == 4)),
    ("rejeitadas: linhas", "SELECT COUNT(*) FROM staging.pnad_covid_rejeitado", len(INVALIDAS)),
    ("rejeitadas: UF inexistente", "SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%UF inexistente%'", 1),
    ("rejeitadas: IDADE", "SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%IDADE%'", 1),
    ("rejeitadas: NU_MES", "SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%NU_MES%'", 1),
    ("rejeitadas: SEXO", "SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%SEXO%'", 1),
    ("rejeitadas: CO_MUNICIPIO", "SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%CO_MUNICIPIO%'", 1),
    ("rejeitadas: não numérico", "SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%numérico%'", 1),
    ("rejeitadas: mal formada", "SELECT COUNT(*) FROM staging.pnad_covid_rejeitado WHERE ds_motivo LIKE '%mal formada%'", 1),
    ("dim_tempo: linhas", "SELECT COUNT(*) FROM dw.dim_tempo", len(competencias)),
    ("dim_tempo: Maio presente", "SELECT COUNT(*) FROM dw.dim_tempo WHERE nu_mes = 5 AND no_mes = 'Maio'", 1),
    ("dim_municipio: linhas", "SELECT COUNT(*) FROM dw.dim_municipio", len(municipios)),
    ("dim_municipio: 'Sao Luis' normalizado (MA)",
     "SELECT COUNT(*) FROM dw.dim_municipio WHERE sg_uf = 'MA' AND no_municipio COLLATE Latin1_General_100_BIN2 = 'Sao Luis'", 1),
    ("dim_municipio: 'Rio de Janeiro' com preposição minúscula",
     "SELECT COUNT(*) FROM dw.dim_municipio WHERE no_municipio COLLATE Latin1_General_100_BIN2 = 'Rio de Janeiro'", 1),
    ("dim_municipio: 'Demais Municipios' de MA e MG",
     "SELECT COUNT(*) FROM dw.dim_municipio WHERE no_municipio = 'Demais Municipios'",
     sum(1 for (_, cap) in municipios if cap is None)),
    ("dim_pessoa: perfis", "SELECT COUNT(*) FROM dw.dim_pessoa", len(perfis)),
    ("dim_pessoa: sexo só M/F", "SELECT COUNT(*) FROM dw.dim_pessoa WHERE sexo NOT IN ('M', 'F')", 0),
    ("dim_pessoa: renda vazia = 'Não aplicável'",
     "SELECT COUNT(*) FROM dw.dim_pessoa WHERE faixa_rendimento = 'Não aplicável'",
     len({p for p in perfis if p[4] is None})),
    ("fato: linhas (grão)", "SELECT COUNT(*) FROM dw.fato_pnad_covid", len(graos)),
    ("fato: pessoas", "SELECT SUM(qt_pessoas) FROM dw.fato_pnad_covid", qt_gravadas),
    ("fato: atendimento_SUS", "SELECT SUM(atendimento_SUS) FROM dw.fato_pnad_covid", qt_sus),
    ("fato: internado", "SELECT SUM(internado) FROM dw.fato_pnad_covid", qt_internado),
    ("fato: sintoma", "SELECT SUM(sintoma) FROM dw.fato_pnad_covid", qt_sintoma),
    ("log usp_carregar_fato: SUCESSO (1 = sim)",
     "SELECT TOP (1) CASE WHEN st_execucao = 'SUCESSO' THEN 1 ELSE 0 END FROM auditoria.log_execucao WHERE no_processo = 'etl.usp_carregar_fato' ORDER BY id_log DESC",
     1),
]

# ---------------------------------------------------------------- SQL de validação
sql = [
    "/* =============================================================================",
    "   Arquivo  : tests/sql/validar_carga_teste.sql",
    "   GERADO por tests/gerar_teste.py. Não edite à mão: altere o gerador.",
    "   Compara o resultado da carga do CSV de teste com os valores esperados.",
    "   ============================================================================= */",
    "USE PNAD_COVID;",
    "SET NOCOUNT ON;",
    "",
    "DECLARE @resultado TABLE (verificacao NVARCHAR(200), esperado INT, obtido INT);",
    "",
]
for nome, consulta, esperado in ESPERADOS:
    nome_sql = nome.replace("'", "''")
    sql.append(f"INSERT INTO @resultado SELECT N'{nome_sql}', {esperado}, ({consulta});")

sql += [
    "",
    "SELECT verificacao, esperado, obtido,",
    "       CASE WHEN esperado = obtido THEN 'OK' ELSE 'FALHOU' END AS situacao",
    "FROM @resultado;",
    "",
    "IF EXISTS (SELECT 1 FROM @resultado WHERE obtido IS NULL OR obtido <> esperado)",
    "    THROW 50100, N'Teste falhou: veja as linhas com situacao = FALHOU.', 1;",
    "",
    "PRINT 'Todas as verificações passaram.';",
    "",
]
sql_path = RAIZ / "sql" / "validar_carga_teste.sql"
sql_path.parent.mkdir(parents=True, exist_ok=True)
sql_path.write_text("\n".join(sql), encoding="utf-8")

print(f"CSV: {csv_path.relative_to(RAIZ.parent)} ({qt_lidas} linhas de dados, {len(INVALIDAS)} inválidas)")
print(f"SQL: {sql_path.relative_to(RAIZ.parent)} ({len(ESPERADOS)} verificações)")

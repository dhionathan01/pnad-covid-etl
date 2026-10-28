"""
Conexão com o SQL Server do projeto e funções para rodar SQL a partir do notebook.

Usa pymssql porque ele já vem com o driver embutido: não precisa instalar o
ODBC Driver da Microsoft no Windows. A senha sai do .env da raiz do projeto,
o mesmo usado pelo docker-compose.
"""

import re
from pathlib import Path

import pandas as pd
import pymssql
from dotenv import dotenv_values


def raiz_projeto() -> Path:
    """Sobe a partir da pasta atual até achar o docker-compose.yml."""
    pasta = Path.cwd().resolve()
    for candidata in [pasta, *pasta.parents]:
        if (candidata / "docker-compose.yml").exists():
            return candidata
    raise FileNotFoundError("Não achei o docker-compose.yml. Abra o notebook de dentro do repositório.")


RAIZ = raiz_projeto()
BANCO_PROJETO = "PNAD_COVID"


def _config() -> dict:
    env = RAIZ / ".env"
    if not env.exists():
        raise FileNotFoundError("Arquivo .env não encontrado na raiz. Copie o .env.example para .env.")
    return dotenv_values(env)


def mensagem_erro(erro: Exception) -> str:
    """O pymssql devolve (código, b'mensagem...'); extrai só o texto útil."""
    args = getattr(erro, "args", ())
    if len(args) >= 2 and isinstance(args[1], (bytes, bytearray)):
        texto = args[1].decode("utf-8", errors="replace")
        return texto.split("DB-Lib error")[0].strip()
    return str(erro)


class Banco:
    """Uma sessão com o SQL Server. Use sempre a mesma instância no notebook."""

    def __init__(self, servidor: str = "localhost", porta: int | None = None):
        cfg = _config()
        self.servidor = servidor
        self.porta = int(porta or cfg.get("MSSQL_PORTA") or 1433)
        self._senha = cfg["MSSQL_SA_PASSWORD"]
        self.conexao = None

    # ----------------------------------------------------------- conexão
    def conectar(self) -> "Banco":
        # autocommit: CREATE DATABASE não roda dentro de transação, e as
        # procedures já controlam as próprias transações.
        self.conexao = pymssql.connect(
            server=self.servidor, port=self.porta, user="sa", password=self._senha,
            database="master", autocommit=True, login_timeout=10, charset="UTF-8",
        )
        return self

    def usar_projeto(self) -> bool:
        """Entra no banco PNAD_COVID quando ele já existe."""
        existe = self.consultar(f"SELECT DB_ID(N'{BANCO_PROJETO}') AS id").iloc[0, 0]
        if existe is not None:
            self.executar(f"USE {BANCO_PROJETO};")
            return True
        return False

    # ----------------------------------------------------------- execução
    def executar(self, sql: str) -> list[pd.DataFrame]:
        """Roda um lote e devolve todos os conjuntos de resultado como DataFrames."""
        cursor = self.conexao.cursor()
        cursor.execute(sql)
        resultados = []
        while True:
            if cursor.description:
                colunas = [c[0] for c in cursor.description]
                resultados.append(pd.DataFrame(cursor.fetchall(), columns=colunas))
            if not cursor.nextset():
                break
        cursor.close()
        return resultados

    def consultar(self, sql: str) -> pd.DataFrame:
        """Primeiro conjunto de resultado de uma consulta."""
        resultados = self.executar(sql)
        return resultados[0] if resultados else pd.DataFrame()

    def executar_script(self, caminho: str | Path) -> int:
        """
        Roda um .sql do projeto. O separador GO é do SSMS/sqlcmd, não do SQL
        Server, então o arquivo é quebrado em lotes aqui, como o sqlcmd faz.
        """
        caminho = Path(caminho)
        if not caminho.is_absolute():
            caminho = RAIZ / caminho
        texto = caminho.read_text(encoding="utf-8")
        lotes = [l for l in re.split(r"^\s*GO\s*;?\s*$", texto, flags=re.M | re.I) if l.strip()]
        for lote in lotes:
            self.executar(lote)
        return len(lotes)

    def log(self, quantidade: int = 10) -> pd.DataFrame:
        """Últimas linhas de auditoria.log_execucao."""
        return self.consultar(f"""
            SELECT TOP ({int(quantidade)}) id_log, no_processo, dt_inicio,
                   DATEDIFF(SECOND, dt_inicio, dt_fim) AS seg,
                   qt_linhas_lidas AS lidas, qt_linhas_gravadas AS gravadas,
                   st_execucao AS status, ds_observacao AS observacao
            FROM auditoria.log_execucao
            ORDER BY id_log DESC;""")

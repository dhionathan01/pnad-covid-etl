"""
Gera as imagens SVG do README com a identidade visual do notebook.

O GitHub não aplica CSS no Markdown, então a capa, o diagrama e a assinatura
viram imagens. Cores, logo e diagrama vêm de notebooks/apoio/identidade.py:
mudou lá, rode de novo e o README acompanha.

Uso (na raiz do projeto, com a .venv):
    .venv/Scripts/python docs/gerar_imagens.py     # Windows
    .venv/bin/python docs/gerar_imagens.py         # Linux / macOS
"""

import sys
from html import escape
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "notebooks"))

from apoio.identidade import COR, LOGO_PATH, svg_arquitetura  # noqa: E402

PASTA = RAIZ / "docs" / "img"
FONTE = "Inter, Segoe UI, Helvetica, Arial, sans-serif"
MONO = "JetBrains Mono, Consolas, Menlo, monospace"

# Mesmo gradiente do LOGO_SVG do notebook.
GRAD_LOGO = (
    '<linearGradient id="djGrad" gradientUnits="userSpaceOnUse" x1="95" y1="90" x2="470" y2="285">'
    '<stop offset="0" stop-color="#18F5FD"/><stop offset="0.28" stop-color="#00A6FE"/>'
    '<stop offset="0.55" stop-color="#5A3BFE"/><stop offset="0.8" stop-color="#A430FC"/>'
    '<stop offset="1" stop-color="#C43CFC"/></linearGradient>'
)


def logo(x: float, y: float, tamanho: float) -> str:
    return (f'<svg x="{x}" y="{y}" width="{tamanho}" height="{tamanho}" viewBox="90 95 382 382">'
            f'<path d="{LOGO_PATH}" fill="url(#djGrad)" fill-rule="evenodd"/></svg>')


def marca(x: float, y: float, tamanho: float, rotulo: str = "Engenharia de Dados") -> str:
    """Logo com o rótulo pequeno em caixa alta e o nome, como em ui.capa()."""
    tx = x + tamanho + 14
    return (logo(x, y, tamanho)
            + f'<text x="{tx}" y="{y + tamanho * 0.42}" fill="{COR["suave"]}" font-size="13" letter-spacing="1.6">{escape(rotulo.upper())}</text>'
            + f'<text x="{tx}" y="{y + tamanho * 0.88}" fill="{COR["texto"]}" font-size="18" font-weight="600">Dhionathan Jobim</text>')


def capa() -> str:
    """Capa do README: a mesma composição de ui.capa() no topo do notebook."""
    largura, altura = 1280, 400
    fatos = [("15", "scripts SQL"), ("20", "functions"), ("9", "procedures"), ("28", "verificações"), ("IBGE 2020", "dados")]

    chips, x = "", 64
    for numero, texto in fatos:
        rotulo = f"{texto} {numero}" if texto == "dados" else f"{numero} {texto}"
        w = len(rotulo) * 8.6 + 30          # largura aproximada da fonte mono em 14px
        partes = ((f'<tspan fill="{COR["suave"]}">{texto} </tspan><tspan fill="{COR["texto"]}" font-weight="700">{numero}</tspan>')
                  if texto == "dados" else
                  (f'<tspan fill="{COR["texto"]}" font-weight="700">{numero}</tspan><tspan fill="{COR["suave"]}"> {texto}</tspan>'))
        chips += (f'<rect x="{x}" y="304" width="{w:.0f}" height="34" rx="17" fill="{COR["card"]}" stroke="{COR["borda"]}"/>'
                  f'<text x="{x + w / 2:.0f}" y="326" text-anchor="middle" font-family="{MONO}" font-size="14">{partes}</text>')
        x += w + 10

    # Aurora: os três brilhos radiais de .dj-aurora, nas mesmas posições.
    aurora = "".join(
        f'<radialGradient id="{i}" cx="{cx}" cy="{cy}" r="{r}"><stop offset="0" stop-color="{cor}" stop-opacity="{op}"/>'
        f'<stop offset="1" stop-color="{cor}" stop-opacity="0"/></radialGradient>'
        for i, cx, cy, r, cor, op in [("a1", "10%", "20%", "45%", "#18F5FD", ".16"),
                                      ("a2", "55%", "0%", "40%", "#5A3BFE", ".20"),
                                      ("a3", "95%", "40%", "45%", "#C43CFC", ".20")]
    )

    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {largura} {altura}" font-family="{FONTE}" '
        f'role="img" aria-label="ETL PNAD Covid-19 em SQL Server, por Dhionathan Jobim">'
        f'<defs>{GRAD_LOGO}{aurora}'
        f'<linearGradient id="titulo" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{COR["marca_texto"]}"/>'
        f'<stop offset="1" stop-color="{COR["marca_clara"]}"/></linearGradient>'
        f'<clipPath id="card"><rect width="{largura}" height="{altura}" rx="24"/></clipPath></defs>'
        f'<g clip-path="url(#card)"><rect width="{largura}" height="{altura}" fill="{COR["fundo"]}"/>'
        + "".join(f'<rect width="{largura}" height="{altura}" fill="url(#{i})"/>' for i in ("a1", "a2", "a3"))
        + "</g>"
        f'<rect x=".5" y=".5" width="{largura - 1}" height="{altura - 1}" rx="24" fill="none" stroke="{COR["borda"]}"/>'
        + marca(64, 52, 48)
        + f'<text x="64" y="186" fill="{COR["texto"]}" font-size="58" font-weight="800" letter-spacing="-2">ETL PNAD Covid-19 em '
          f'<tspan fill="url(#titulo)">SQL Server</tspan></text>'
        + f'<text fill="{COR["suave"]}" font-size="20">'
          f'<tspan x="64" y="236">Carga dos microdados da PNAD Covid-19 (IBGE, 2020): leitura do CSV, validação linha a linha,</tspan>'
          f'<tspan x="64" y="266">staging, normalização e Data Warehouse em estrela, com log de cada etapa.</tspan></text>'
        + chips
        + f'<text x="{largura - 64}" y="78" text-anchor="end" fill="{COR["suave"]}" font-family="{MONO}" font-size="13">MS SQL Server Operação</text>'
        + f'<text x="{largura - 64}" y="98" text-anchor="end" fill="{COR["suave"]}" font-family="{MONO}" font-size="13">MBA Engenharia de Dados · PUC Minas</text>'
        + "</svg>"
    )


def assinatura() -> str:
    """Rodapé do README: logo, nome e disciplina."""
    largura, altura = 1280, 112
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {largura} {altura}" font-family="{FONTE}" '
        f'role="img" aria-label="Dhionathan Jobim, Engenharia de Dados">'
        f'<defs>{GRAD_LOGO}</defs>'
        f'<rect x=".5" y=".5" width="{largura - 1}" height="{altura - 1}" rx="18" fill="{COR["fundo"]}" stroke="{COR["borda"]}"/>'
        + marca(40, 32, 48)
        + f'<text x="{largura - 40}" y="52" text-anchor="end" fill="{COR["suave"]}" font-family="{MONO}" font-size="13">MBA em Engenharia de Dados · PUC Minas</text>'
        + f'<text x="{largura - 40}" y="74" text-anchor="end" fill="{COR["marca_texto"]}" font-family="{MONO}" font-size="13">ETL PNAD Covid-19 → SQL Server</text>'
        + "</svg>"
    )


if __name__ == "__main__":
    PASTA.mkdir(parents=True, exist_ok=True)
    for nome, svg in [("capa.svg", capa()), ("arquitetura.svg", svg_arquitetura(fundo=True)), ("assinatura.svg", assinatura())]:
        (PASTA / nome).write_text(svg, encoding="utf-8")
        print(f"docs/img/{nome}")

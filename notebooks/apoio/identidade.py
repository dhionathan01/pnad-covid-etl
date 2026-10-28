"""
Identidade visual Dhionathan Jobim para as saídas do notebook.

Os valores vêm do pacote @lifehub/ui (src/design-tokens.ts) e são os mesmos da
página docs/index.html. As saídas são cartões escuros autocontidos: cada HTML
traz o próprio <style>, então o visual fica igual no Jupyter, no VS Code e no
GitHub, em tema claro ou escuro.
"""

import numbers
from html import escape

import pandas as pd
from IPython.display import HTML, display

# ---------------------------------------------------------------- tokens
COR = {
    "fundo": "#09090B",          # colors.background
    "card": "#121216",           # colors.card
    "card2": "#1B1B24",          # gradients.card[1]
    "borda": "#27272A",          # colors.border
    "texto": "#FAFAFA",          # colors.foreground
    "suave": "#A1A1AA",          # colors.mutedForeground
    "marca": "#4A90E2",          # colors.primary
    "marca_texto": "#86B8EA",    # primaryText (dark)
    "marca_clara": "#A8C0F0",    # gradients.text[1]
    "tinta": "rgba(74, 144, 226, 0.10)",  # alpha.primary10
    "ok": "#4ADE80",
    "aviso": "#FBBF24",
    "erro": "#F87171",
}
# Paleta categórica dos gráficos (charts.categorical), ordem fixa.
PALETA = ["#4A90E2", "#D97706", "#A430FC", "#16A34A", "#0891B2", "#DB2777"]

LOGO_PATH = "M 97.250 100.782 L 95 101.139 95 127.510 L 95 153.881 167.250 154.236 C 247.035 154.628, 242.032 154.237, 256.641 161.215 C 265.774 165.578, 275.521 175.466, 280.158 185.073 C 286.194 197.578, 286.500 200.010, 286.500 235.500 C 286.500 266.355, 286.417 267.750, 284.167 274.500 C 277.692 293.928, 270.204 301.116, 235.721 321 L 214.044 333.500 214.022 362.857 C 214.001 390.410, 214.108 392.173, 215.750 391.543 C 220.587 389.687, 298.383 342.189, 303.960 337.686 C 323.034 322.286, 336.464 298.567, 340.019 274.004 C 341.564 263.327, 341.225 204.072, 339.555 192.996 C 337.873 181.838, 333.978 168.921, 329.757 160.500 C 318.043 137.133, 293.085 115.196, 268.404 106.574 C 252.725 101.096, 251.302 101.009, 172.500 100.706 C 132.350 100.552, 98.487 100.586, 97.250 100.782 M 415.500 108.381 C 407.800 112.951, 390.587 123.106, 377.250 130.949 C 355.209 143.911, 353.003 145.451, 353.032 147.855 C 353.049 149.310, 353.713 155.225, 354.507 161 C 355.301 166.775, 356.692 177.350, 357.599 184.500 C 358.506 191.650, 359.607 197.892, 360.045 198.371 C 360.826 199.224, 375.134 191.270, 401.909 175.099 C 409.284 170.644, 415.487 167, 415.695 167 C 415.902 167, 415.926 200.863, 415.747 242.250 C 415.460 308.744, 415.233 318.041, 413.790 322.148 C 408.509 337.181, 401.890 344.361, 383.500 355.006 C 378.550 357.871, 368.875 363.468, 362 367.444 C 346.099 376.639, 321.879 390.787, 311.346 397.033 C 306.861 399.692, 302.560 402.010, 301.787 402.184 C 301.014 402.358, 292.822 398.298, 283.582 393.162 C 273.881 387.769, 266.038 384.018, 265.020 384.284 C 264.051 384.538, 254.987 389.653, 244.879 395.650 C 234.771 401.648, 221.232 409.670, 214.793 413.477 C 201.970 421.060, 201.949 421.104, 209.346 425.284 C 211.631 426.575, 230.515 437.409, 251.311 449.359 C 287.743 470.294, 289.219 471.037, 291.811 469.729 C 293.290 468.983, 319.475 453.509, 350 435.344 C 380.525 417.178, 412.144 398.394, 420.265 393.601 C 443.248 380.039, 451.929 371.633, 459.612 355.500 C 466.939 340.118, 466.500 348.877, 466.500 218 L 466.500 100.500 448 100.287 L 429.500 100.074 415.500 108.381 M 95.245 268.557 L 95.500 361.145 112.500 370.666 C 121.850 375.903, 135.800 383.691, 143.500 387.973 C 151.200 392.256, 164.862 399.864, 173.859 404.880 C 182.857 409.896, 190.845 414, 191.609 414 C 192.773 414, 193 407.563, 193 374.500 L 193 335 172.506 335 L 152.012 335 151.756 255.750 L 151.500 176.500 123.245 176.234 L 94.990 175.969 95.245 268.557"

LOGO_SVG = (
    '<svg class="dj-logo" viewBox="90 95 382 382" aria-hidden="true">'
    '<defs><linearGradient id="djGrad" gradientUnits="userSpaceOnUse" x1="95" y1="90" x2="470" y2="285">'
    '<stop offset="0" stop-color="#18F5FD"/><stop offset="0.28" stop-color="#00A6FE"/>'
    '<stop offset="0.55" stop-color="#5A3BFE"/><stop offset="0.8" stop-color="#A430FC"/>'
    '<stop offset="1" stop-color="#C43CFC"/></linearGradient></defs>'
    f'<path d="{LOGO_PATH}" fill="url(#djGrad)" fill-rule="evenodd"/></svg>'
)

CSS = f"""
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;600&display=swap');
.dj {{ font-family: Inter, "Segoe UI", system-ui, sans-serif; color: {COR['texto']}; background: {COR['fundo']};
      border: 1px solid {COR['borda']}; border-radius: 12px; padding: 18px 22px; line-height: 1.6;
      font-size: 14.5px; margin: 4px 0; position: relative; overflow: hidden; }}
.dj * {{ box-sizing: border-box; }}
.dj code, .dj .mono {{ font-family: "JetBrains Mono", Consolas, monospace; font-size: 12.5px; }}
.dj code {{ background: {COR['tinta']}; color: {COR['marca_texto']}; padding: 1px 6px; border-radius: 5px; }}
.dj-aurora::before {{ content: ""; position: absolute; inset: 0; pointer-events: none;
      background: radial-gradient(40% 70% at 10% 20%, rgba(24,245,253,.13), transparent 70%),
                  radial-gradient(35% 60% at 55% 0%, rgba(90,59,254,.15), transparent 70%),
                  radial-gradient(40% 70% at 95% 40%, rgba(196,60,252,.16), transparent 70%); }}
.dj-capa {{ padding: 28px 26px; }}
.dj-capa > * {{ position: relative; }}
.dj-marca {{ display: flex; align-items: center; gap: 10px; margin-bottom: 18px; }}
.dj-logo {{ width: 34px; height: 34px; display: block; }}
.dj-marca small {{ display: block; font-size: 11px; color: {COR['suave']}; letter-spacing: .08em; text-transform: uppercase; line-height: 1.2; }}
.dj-marca strong {{ display: block; font-size: 15px; font-weight: 600; line-height: 1.2; }}
.dj-titulo {{ font-size: 32px; font-weight: 800; letter-spacing: -.035em; line-height: 1.1; margin: 0 0 12px; }}
.dj-grad {{ background: linear-gradient(135deg, {COR['marca_texto']}, {COR['marca_clara']});
      -webkit-background-clip: text; background-clip: text; color: transparent; }}
.dj-lead {{ color: {COR['suave']}; max-width: 70ch; margin: 0; }}
.dj-fatos {{ display: flex; flex-wrap: wrap; gap: 8px; margin-top: 16px; }}
.dj-fatos span {{ font-family: "JetBrains Mono", Consolas, monospace; font-size: 12px; padding: 4px 10px;
      border-radius: 999px; border: 1px solid {COR['borda']}; color: {COR['suave']}; background: {COR['card']}; }}
.dj-fatos b {{ color: {COR['texto']}; }}
.dj-secao {{ display: flex; gap: 14px; align-items: flex-start; }}
.dj-num {{ flex-shrink: 0; width: 38px; height: 38px; border-radius: 10px; display: grid; place-items: center;
      font-family: "JetBrains Mono", Consolas, monospace; font-weight: 600; font-size: 14px;
      color: {COR['marca_texto']}; background: {COR['tinta']}; border: 1px solid {COR['marca']}; }}
.dj-secao h2 {{ margin: 2px 0 4px; font-size: 21px; font-weight: 700; letter-spacing: -.02em; color: {COR['texto']}; }}
.dj-secao p {{ margin: 0; color: {COR['suave']}; max-width: 75ch; }}
.dj-rotulo {{ font-family: "JetBrains Mono", Consolas, monospace; font-size: 11px; color: {COR['marca_texto']};
      text-transform: uppercase; letter-spacing: .07em; margin-bottom: 8px; }}
.dj-tabela-wrap {{ overflow-x: auto; border: 1px solid {COR['borda']}; border-radius: 10px; }}
.dj table {{ border-collapse: collapse; width: 100%; font-size: 13px; margin: 0; }}
.dj th, .dj td {{ text-align: left; padding: 7px 11px; border-bottom: 1px solid {COR['borda']}; vertical-align: top;
      color: {COR['texto']}; background: transparent; }}
.dj th {{ font-size: 11px; text-transform: uppercase; letter-spacing: .07em; color: {COR['suave']};
      font-weight: 600; background: {COR['card']}; white-space: nowrap; }}
.dj tr:last-child td {{ border-bottom: 0; }}
.dj td.num {{ text-align: right; font-variant-numeric: tabular-nums; font-family: "JetBrains Mono", Consolas, monospace; }}
.dj-pill {{ display: inline-flex; align-items: center; gap: 6px; font-family: "JetBrains Mono", Consolas, monospace;
      font-size: 11.5px; padding: 2px 9px; border-radius: 999px; border: 1px solid {COR['borda']}; white-space: nowrap; }}
.dj-pill i {{ width: 7px; height: 7px; border-radius: 50%; display: inline-block; }}
.dj-pill.ok i {{ background: {COR['ok']}; }} .dj-pill.aviso i {{ background: {COR['aviso']}; }}
.dj-pill.erro i {{ background: {COR['erro']}; }} .dj-pill.info i {{ background: {COR['marca']}; }}
.dj-aviso {{ display: flex; gap: 12px; align-items: flex-start; border-left: 3px solid {COR['marca']}; }}
.dj-aviso.ok {{ border-left-color: {COR['ok']}; }} .dj-aviso.erro {{ border-left-color: {COR['erro']}; }}
.dj-aviso.aviso {{ border-left-color: {COR['aviso']}; }}
.dj-aviso strong {{ display: block; margin-bottom: 2px; }}
.dj-aviso span {{ color: {COR['suave']}; }}
.dj-rodape {{ color: {COR['suave']}; font-size: 12px; margin-top: 8px; }}
.dj-diagrama {{ overflow-x: auto; }}
.dj-diagrama svg {{ min-width: 700px; width: 100%; height: auto; display: block; }}
</style>
"""


def _mostrar(corpo: str) -> None:
    display(HTML(CSS + corpo))


# ---------------------------------------------------------------- blocos


def capa(titulo: str, destaque: str, texto: str, fatos: list[str]) -> None:
    """Abertura do notebook com logo, título em gradiente e aurora da marca."""
    chips = "".join(f"<span>{f}</span>" for f in fatos)
    _mostrar(
        f'<div class="dj dj-capa dj-aurora">'
        f'<div class="dj-marca">{LOGO_SVG}<span><small>Engenharia de Dados</small>'
        f"<strong>Dhionathan Jobim</strong></span></div>"
        f'<h1 class="dj-titulo">{escape(titulo)} <span class="dj-grad">{escape(destaque)}</span></h1>'
        f'<p class="dj-lead">{texto}</p><div class="dj-fatos">{chips}</div></div>'
    )


def secao(numero: int, titulo: str, resumo: str) -> None:
    """Cabeçalho de cada parte do notebook."""
    _mostrar(
        f'<div class="dj"><div class="dj-secao"><div class="dj-num">{numero:02d}</div>'
        f"<div><h2>{escape(titulo)}</h2><p>{resumo}</p></div></div></div>"
    )


def aviso(titulo: str, texto: str = "", tipo: str = "info") -> None:
    """Mensagem de resultado: tipo = info, ok, aviso ou erro."""
    _mostrar(
        f'<div class="dj dj-aviso {tipo}"><div><strong>{escape(titulo)}</strong>'
        f"<span>{texto}</span></div></div>"
    )


_STATUS = {"SUCESSO": "ok", "SUCESSO PARCIAL": "aviso", "ERRO": "erro", "EM EXECUCAO": "info", "OK": "ok", "FALHOU": "erro"}


def _celula(valor) -> str:
    if valor is None or (not isinstance(valor, str) and pd.api.types.is_scalar(valor) and pd.isna(valor)):
        return '<td style="color:#A1A1AA">NULL</td>'
    if isinstance(valor, str) and valor in _STATUS:
        return f'<td><span class="dj-pill {_STATUS[valor]}"><i></i>{escape(valor)}</span></td>'
    if isinstance(valor, numbers.Number) and not isinstance(valor, bool):
        texto = f"{valor:,.0f}".replace(",", ".") if float(valor).is_integer() else f"{valor:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
        return f'<td class="num">{texto}</td>'
    return f"<td>{escape(str(valor))}</td>"


def tabela(df: pd.DataFrame, rotulo: str = "", max_linhas: int = 30, rodape: str = "") -> None:
    """DataFrame no visual da marca; status do log viram pílulas coloridas."""
    if df is None or df.empty:
        aviso(rotulo or "Consulta", "Nenhuma linha retornada.", "aviso")
        return
    exibido = df.head(max_linhas)
    cab = "".join(f"<th>{escape(str(c))}</th>" for c in exibido.columns)
    linhas = "".join("<tr>" + "".join(_celula(v) for v in linha) + "</tr>" for linha in exibido.itertuples(index=False))
    extra = f"Mostrando {max_linhas} de {len(df)} linhas. " if len(df) > max_linhas else ""
    rot = f'<div class="dj-rotulo">{escape(rotulo)}</div>' if rotulo else ""
    rod = f'<div class="dj-rodape">{extra}{rodape}</div>' if (extra or rodape) else ""
    _mostrar(f'<div class="dj">{rot}<div class="dj-tabela-wrap"><table><thead><tr>{cab}</tr></thead>'
             f"<tbody>{linhas}</tbody></table></div>{rod}</div>")


def codigo(texto: str, rotulo: str = "") -> None:
    """Trecho de SQL ou comando em destaque."""
    rot = f'<div class="dj-rotulo">{escape(rotulo)}</div>' if rotulo else ""
    _mostrar(f'<div class="dj">{rot}<pre class="mono" style="margin:0;white-space:pre-wrap;color:#FAFAFA">'
             f"{escape(texto.strip())}</pre></div>")


def diagrama_arquitetura() -> None:
    """Fluxo do projeto: CSV, staging, transformação, DW e log."""
    c = COR
    caixa = lambda x, w, t1, t2, banco=False: (
        f'<rect x="{x}" y="40" width="{w}" height="64" rx="10" fill="{c["tinta"] if banco else c["card2"]}" '
        f'stroke="{c["marca"] if banco else c["borda"]}"/>'
        f'<text x="{x + w / 2}" y="68" text-anchor="middle" fill="{c["texto"]}" font-size="13" font-weight="600">{t1}</text>'
        f'<text x="{x + w / 2}" y="86" text-anchor="middle" fill="{c["suave"]}" font-size="10.5" font-family="JetBrains Mono, monospace">{t2}</text>'
    )
    seta = lambda x1, x2: f'<path d="M{x1} 72H{x2}" stroke="{c["marca"]}" stroke-width="1.6" fill="none" marker-end="url(#p)"/>'
    svg = (
        '<svg viewBox="0 0 900 230" xmlns="http://www.w3.org/2000/svg" font-family="Inter, Segoe UI, sans-serif">'
        f'<defs><marker id="p" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto">'
        f'<path d="M0 0L10 5L0 10z" fill="{c["marca"]}"/></marker>'
        f'<marker id="pl" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto">'
        f'<path d="M0 0L10 5L0 10z" fill="{c["erro"]}"/></marker></defs>'
        + caixa(10, 120, "CSV IBGE", "PNAD_COVID_*.csv")
        + caixa(160, 130, "Leitura e validação", "usp_carregar")
        + caixa(320, 110, "Staging", "schema staging", True)
        + caixa(460, 130, "Normalização", "functions etl.fn_*")
        + caixa(620, 120, "Dimensões e fato", "usp_carregar_dim_*")
        + caixa(770, 120, "Data Warehouse", "schema dw", True)
        + seta(130, 158) + seta(290, 318) + seta(430, 458) + seta(590, 618) + seta(740, 768)
        + f'<rect x="300" y="170" width="300" height="48" rx="10" fill="{c["card2"]}" stroke="{c["erro"]}" stroke-dasharray="4 3"/>'
        + f'<text x="450" y="191" text-anchor="middle" fill="{c["texto"]}" font-size="13" font-weight="600">auditoria.log_execucao</text>'
        + f'<text x="450" y="208" text-anchor="middle" fill="{c["suave"]}" font-size="10.5" font-family="JetBrains Mono, monospace">lidas · gravadas · status · observação</text>'
        + "".join(
            f'<path d="{d}" stroke="{c["erro"]}" stroke-width="1.2" fill="none" stroke-dasharray="3 3" opacity=".75" marker-end="url(#pl)"/>'
            for d in ("M225 104V194H298", "M375 104V168", "M680 104V194H602")
        )
        + f'<rect x="130" y="128" width="150" height="26" rx="6" fill="{c["card2"]}" stroke="{c["erro"]}" stroke-dasharray="4 3"/>'
        + f'<text x="205" y="145" text-anchor="middle" fill="{c["suave"]}" font-size="10.5" font-family="JetBrains Mono, monospace">pnad_covid_rejeitado</text>'
        + "</svg>"
    )
    _mostrar(f'<div class="dj"><div class="dj-rotulo">Arquitetura</div><div class="dj-diagrama">{svg}</div></div>')


def estilo_graficos() -> None:
    """Deixa o matplotlib com fundo, texto, grade e paleta da marca."""
    import matplotlib as mpl
    from cycler import cycler
    from matplotlib import font_manager

    # Usa a primeira fonte instalada da lista, sem encher a saída de avisos.
    instaladas = {f.name for f in font_manager.fontManager.ttflist}
    fonte = next((f for f in ("Inter", "Segoe UI", "Helvetica Neue", "Arial") if f in instaladas), "DejaVu Sans")

    mpl.rcParams.update({
        "figure.facecolor": COR["fundo"],
        "axes.facecolor": COR["fundo"],
        "savefig.facecolor": COR["fundo"],
        "axes.edgecolor": COR["borda"],
        "axes.labelcolor": COR["suave"],
        "axes.titlecolor": COR["texto"],
        "axes.titleweight": "bold",
        "axes.titlesize": 13,
        "axes.titlelocation": "left",
        "axes.grid": True,
        "axes.spines.top": False,
        "axes.spines.right": False,
        "grid.color": COR["borda"],
        "grid.linewidth": 0.8,
        "xtick.color": COR["suave"],
        "ytick.color": COR["suave"],
        "text.color": COR["texto"],
        "legend.frameon": False,
        "font.family": fonte,
        "axes.prop_cycle": cycler(color=PALETA),
        "figure.dpi": 110,
    })

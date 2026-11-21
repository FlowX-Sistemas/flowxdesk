"""Gera ícones derivados (Android + bandeja Windows) a partir do kit em branding/.
Rodar só quando o kit de marca mudar: python -I scripts/gen_icons.py
Fonte do kit: D:\\Sistemas\\crm-comercial\\public\\brand\\flowxdesk (sessão CRM FlowX).
"""
import pathlib
from PIL import Image, ImageDraw

B = pathlib.Path(__file__).resolve().parent.parent / "branding"
CRM = pathlib.Path(r"D:\Sistemas\crm-comercial\public\brand\flowxdesk")
app = Image.open(B / "flowxdesk-1024.png").convert("RGBA")
mark = Image.open(CRM / "flowx-simbolo-sem-fundo-1024.png").convert("RGBA")
white = Image.open(B / "flowxdesk-tray-white-256.png").convert("RGBA")

DENS = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for d, k in DENS.items():
    out = B / "android" / f"mipmap-{d}"
    out.mkdir(parents=True, exist_ok=True)
    s = round(48 * k)
    icon = app.resize((s, s), Image.LANCZOS)
    icon.save(out / "ic_launcher.png")
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, s - 1, s - 1), fill=255)
    rnd = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    rnd.paste(icon, (0, 0), mask)
    rnd.save(out / "ic_launcher_round.png")
    # adaptive: canvas 108dp, símbolo dentro da zona segura (~60%)
    c = round(108 * k)
    fg = Image.new("RGBA", (c, c), (0, 0, 0, 0))
    m = round(c * 0.6)
    fg.alpha_composite(mark.resize((m, m), Image.LANCZOS), ((c - m) // 2, (c - m) // 2))
    fg.save(out / "ic_launcher_foreground.png")
    n = round(24 * k)
    white.resize((n, n), Image.LANCZOS).save(out / "ic_stat_logo.png")

vals = B / "android" / "values"
vals.mkdir(parents=True, exist_ok=True)
(vals / "ic_launcher_background.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    '    <color name="ic_launcher_background">#17161a</color>\n</resources>\n', encoding="utf-8")

app.save(B / "tray-icon.ico", sizes=[(16, 16), (24, 24), (32, 32)])
assert (B / "android/mipmap-xxxhdpi/ic_launcher_foreground.png").exists()
print("ok")

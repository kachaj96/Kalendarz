"""Generuje ikonę aplikacji: kartka kalendarza z ukośnych błękitnych kształtów (w stylu znaczka Flutter).

Uruchom z katalogu głównego repozytorium: python3 tool/make_icon.py
Wymaga Pillow. Pliki trafiają do android/app/src/main/res.
"""
from pathlib import Path

from PIL import Image, ImageDraw

RES = Path("android/app/src/main/res")
BG = (255, 255, 255, 255)
LIGHT = (84, 197, 248, 255)   # jasny błękit z palety Flutter
MID = (41, 182, 246, 255)
DARK = (1, 87, 155, 255)
DEEP = (0, 60, 120, 255)
WHITE = (255, 255, 255, 255)
SS = 4  # supersampling


def calendar(size, monochrome=False):
    """Rysunek mieści się w środkowych ~66% płótna (strefa bezpieczna ikon adaptacyjnych)."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = s / 100.0

    k = 0.85  # skala tak, by rysunek mieścił się w okrągłej masce (widoczne 72 z 108 dp)

    def poly(points, fill):
        d.polygon([((50 + (x - 50) * k) * u, (50 + (y - 52) * k + 2) * u) for x, y in points], fill=fill)

    mono = (0, 0, 0, 255)
    clear = (0, 0, 0, 0)

    # Korpus kartki ze ściętym rogiem (zagięcie jak w znaczku Flutter).
    poly([(23, 31), (77, 31), (77, 63), (62, 78), (23, 78)], mono if monochrome else LIGHT)
    # Zagięty róg.
    if not monochrome:
        poly([(62, 78), (77, 63), (62, 63)], DARK)

    # Ciemny nagłówek ze skośnym cięciem po prawej.
    if monochrome:
        poly([(23, 31), (77, 31), (77, 43.2), (23, 43.2)], clear)
        poly([(23, 31), (77, 31), (77, 41.6), (23, 41.6)], mono)
    else:
        poly([(23, 31), (77, 31), (77, 43), (23, 43)], DARK)

    # Dwa zaczepy jako skośne równoległoboki.
    for x in (33, 61):
        poly(
            [(x, 24), (x + 6, 24), (x + 4, 36), (x - 2, 36)],
            mono if monochrome else MID,
        )

    # Siatka dni: białe kwadraty ze ściętym rogiem, pierwszy to "dzisiaj".
    cols, rows = 3, 2
    for r in range(rows):
        for c in range(cols):
            x = 30 + c * 14.5
            y = 50 + r * 12
            if r == rows - 1 and c == cols - 1:
                continue  # tu zagięty róg
            w = 9.5
            cut = 2.6
            pts = [(x, y), (x + w - cut, y), (x + w, y + cut), (x + w, y + w - 1), (x, y + w - 1)]
            if monochrome:
                poly(pts, clear)
            else:
                poly(pts, DEEP if (r, c) == (0, 0) else WHITE)
    return img.resize((size, size), Image.LANCZOS)


def legacy(size):
    """Pełna ikona dla starszych Androidów (przed 8.0): biały zaokrąglony kwadrat z kartką."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, s, s), radius=int(s * 0.22), fill=BG)
    big = calendar(size * 2).resize((s, s), Image.LANCZOS)
    img.alpha_composite(big)
    return img.resize((size, size), Image.LANCZOS)


densities = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
for name, scale in densities.items():
    fg = int(108 * scale)
    out = RES / f"drawable-{name}"
    out.mkdir(parents=True, exist_ok=True)
    calendar(fg).save(out / "ic_launcher_foreground.png")
    calendar(fg, monochrome=True).save(out / "ic_launcher_monochrome.png")
    legacy(int(48 * scale)).save(RES / f"mipmap-{name}" / "ic_launcher.png")

(RES / "mipmap-anydpi-v26").mkdir(exist_ok=True)
(RES / "mipmap-anydpi-v26" / "ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
    '    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n'
    "</adaptive-icon>\n"
)
(RES / "values" / "colors.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    "<resources>\n"
    '    <color name="ic_launcher_background">#FFFFFF</color>\n'
    "</resources>\n"
)
print("gotowe")

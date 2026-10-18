"""Generuje ikonę aplikacji (kartka kalendarza z kolorowymi kropkami kategorii).

Uruchom z katalogu głównego repozytorium: python3 tool/make_icon.py
Wymaga Pillow. Pliki trafiają do android/app/src/main/res.
"""
from pathlib import Path

from PIL import Image, ImageDraw

RES = Path("android/app/src/main/res")
BG = (52, 84, 209, 255)  # indygo z motywu aplikacji
INK = (31, 47, 122, 255)
WHITE = (255, 255, 255, 255)
DOTS = [
    (199, 95, 0),    # zakupy
    (47, 111, 222),  # praca
    (209, 52, 56),   # zdrowie
    (94, 140, 10),   # sport
    (123, 79, 208),  # rodzina
    (18, 128, 138),  # dom
]
SS = 4  # supersampling


def calendar(size, monochrome=False):
    """Kartka kalendarza narysowana w obrębie środkowych 66% płótna (strefa bezpieczna ikon adaptacyjnych)."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = s / 100.0

    # Kartka: 30..70 w poziomie jest za wąskie, więc bierzemy 22..78 (56 jednostek) i 26..76 w pionie.
    box = (22 * u, 27 * u, 78 * u, 77 * u)
    ink = (0, 0, 0, 255) if monochrome else WHITE
    d.rounded_rectangle(box, radius=7 * u, fill=ink)

    # Pasek nagłówka i dwa zaczepy.
    if monochrome:
        d.rectangle((22 * u, 40 * u, 78 * u, 41.6 * u), fill=(0, 0, 0, 0))
    else:
        d.rounded_rectangle((22 * u, 27 * u, 78 * u, 41 * u), radius=7 * u, fill=INK)
        d.rectangle((22 * u, 34 * u, 78 * u, 41 * u), fill=INK)
    for x in (36, 64):
        d.rounded_rectangle(
            (x * u - 2.2 * u, 21.5 * u, x * u + 2.2 * u, 32 * u),
            radius=2.2 * u,
            fill=(0, 0, 0, 255) if monochrome else WHITE,
        )

    # Siatka kropek w kolorach kategorii, pierwsza to "dzisiaj".
    for i, color in enumerate(DOTS):
        cx = (33 + (i % 3) * 17) * u
        cy = (53 + (i // 3) * 15) * u
        r = 5.2 * u
        if monochrome:
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(0, 0, 0, 0))
        else:
            if i == 0:
                d.ellipse((cx - r - 1.6 * u, cy - r - 1.6 * u, cx + r + 1.6 * u, cy + r + 1.6 * u), fill=BG)
                d.ellipse((cx - r + 1 * u, cy - r + 1 * u, cx + r - 1 * u, cy + r - 1 * u), fill=WHITE)
                d.ellipse((cx - r + 2 * u, cy - r + 2 * u, cx + r - 2 * u, cy + r - 2 * u), fill=color + (255,))
            else:
                d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color + (255,))
    return img.resize((size, size), Image.LANCZOS)


def legacy(size):
    """Pełna ikona dla starszych Androidów (przed 8.0): zaokrąglony kwadrat z kartką."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, s, s), radius=int(s * 0.22), fill=BG)
    big = calendar(size * 2).resize((int(s * 1.0), int(s * 1.0)), Image.LANCZOS)
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
    '    <color name="ic_launcher_background">#3454D1</color>\n'
    "</resources>\n"
)
print("gotowe")

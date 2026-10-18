"""Generuje zasoby Androida dla czterech widżetów (układy, kolory, opisy) oraz WidgetIds.kt.

Układy mają po kilkadziesiąt pól o powtarzalnych nazwach, więc łatwiej je wygenerować niż pisać.
Uruchom z katalogu głównego repozytorium: python3 tool/gen_widgets.py
"""
from pathlib import Path

RES = Path("android/app/src/main/res")
KT = Path("android/app/src/main/kotlin/com/kachaj96/kalendarz/widgets")
A = 'xmlns:android="http://schemas.android.com/apk/res/android"'
LIST_ROWS = 6
WEEK_BARS = 4
MONTH_ROWS = 6


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def header(title_id="w_title", sub_id="w_subtitle"):
    return f"""
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:gravity="center_vertical"
        android:orientation="horizontal">
        <TextView
            android:id="@+id/{title_id}"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:ellipsize="end"
            android:maxLines="1"
            android:text="Kalendarz"
            android:textColor="@color/widget_fg"
            android:textSize="15sp"
            android:textStyle="bold" />
        <TextView
            android:id="@+id/{sub_id}"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:maxLines="1"
            android:textColor="@color/widget_fg2"
            android:textSize="11.5sp" />
    </LinearLayout>"""


def empty_text():
    return """
    <TextView
        android:id="@+id/w_empty"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:paddingTop="8dp"
        android:text="Otwórz aplikację, żeby wczytać wpisy."
        android:textColor="@color/widget_fg2"
        android:textSize="12.5sp" />"""


def list_layout():
    rows = []
    for i in range(LIST_ROWS):
        rows.append(f"""
    <LinearLayout
        android:id="@+id/row_{i}"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:gravity="center_vertical"
        android:orientation="horizontal"
        android:paddingTop="3dp"
        android:paddingBottom="3dp"
        android:visibility="gone">
        <TextView
            android:id="@+id/row_{i}_time"
            android:layout_width="44dp"
            android:layout_height="wrap_content"
            android:maxLines="1"
            android:textColor="@color/widget_fg2"
            android:textSize="12sp"
            android:textStyle="bold" />
        <FrameLayout
            android:id="@+id/row_{i}_bar"
            android:layout_width="3dp"
            android:layout_height="30dp"
            android:background="@color/widget_accent" />
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_marginStart="8dp"
            android:layout_weight="1"
            android:orientation="vertical">
            <TextView
                android:id="@+id/row_{i}_title"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:ellipsize="end"
                android:maxLines="1"
                android:textColor="@color/widget_fg"
                android:textSize="13sp"
                android:textStyle="bold" />
            <TextView
                android:id="@+id/row_{i}_sub"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:ellipsize="end"
                android:maxLines="1"
                android:textColor="@color/widget_fg2"
                android:textSize="11sp" />
        </LinearLayout>
    </LinearLayout>""")
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!-- Wygenerowane przez tool/gen_widgets.py -->
<LinearLayout {A}
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_background"
    android:orientation="vertical"
    android:padding="14dp">{header()}{empty_text()}{''.join(rows)}
</LinearLayout>
"""


def week_layout():
    cols = []
    for d in range(7):
        bars = "".join(f"""
            <TextView
                android:id="@+id/wk_{d}_bar_{b}"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:layout_marginTop="2dp"
                android:background="@color/widget_accent"
                android:ellipsize="end"
                android:maxLines="1"
                android:paddingStart="2dp"
                android:paddingTop="1dp"
                android:paddingEnd="2dp"
                android:paddingBottom="1dp"
                android:textColor="#FFFFFF"
                android:textSize="9sp"
                android:textStyle="bold"
                android:visibility="gone" />""" for b in range(WEEK_BARS))
        cols.append(f"""
        <LinearLayout
            android:id="@+id/wk_{d}"
            android:layout_width="0dp"
            android:layout_height="match_parent"
            android:layout_marginStart="1dp"
            android:layout_marginEnd="1dp"
            android:layout_weight="1"
            android:gravity="center_horizontal"
            android:orientation="vertical">
            <TextView
                android:id="@+id/wk_{d}_name"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:textAllCaps="true"
                android:textColor="@color/widget_fg2"
                android:textSize="10sp"
                android:textStyle="bold" />
            <TextView
                android:id="@+id/wk_{d}_num"
                android:layout_width="24dp"
                android:layout_height="24dp"
                android:layout_marginTop="1dp"
                android:gravity="center"
                android:textColor="@color/widget_fg"
                android:textSize="12.5sp"
                android:textStyle="bold" />{bars}
            <TextView
                android:id="@+id/wk_{d}_more"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:textColor="@color/widget_fg2"
                android:textSize="9sp"
                android:visibility="gone" />
        </LinearLayout>""")
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!-- Wygenerowane przez tool/gen_widgets.py -->
<LinearLayout {A}
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_background"
    android:orientation="vertical"
    android:padding="12dp">{header()}
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:layout_marginTop="6dp"
        android:orientation="horizontal">{''.join(cols)}
    </LinearLayout>
</LinearLayout>
"""


def month_layout():
    names = "".join(f"""
        <TextView
            android:id="@+id/mh_{c}"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:gravity="center"
            android:textColor="@color/widget_fg2"
            android:textSize="10sp"
            android:textStyle="bold" />""" for c in range(7))
    rows = []
    for r in range(MONTH_ROWS):
        cells = "".join(f"""
        <LinearLayout
            android:id="@+id/mc_{r}_{c}"
            android:layout_width="0dp"
            android:layout_height="match_parent"
            android:layout_weight="1"
            android:gravity="center_horizontal"
            android:orientation="vertical">
            <TextView
                android:id="@+id/mn_{r}_{c}"
                android:layout_width="22dp"
                android:layout_height="22dp"
                android:gravity="center"
                android:textColor="@color/widget_fg"
                android:textSize="12sp"
                android:textStyle="bold" />
            <TextView
                android:id="@+id/md_{r}_{c}"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:includeFontPadding="false"
                android:maxLines="1"
                android:textSize="8sp" />
        </LinearLayout>""" for c in range(7))
        rows.append(f"""
    <LinearLayout
        android:id="@+id/mr_{r}"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:orientation="horizontal">{cells}
    </LinearLayout>""")
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!-- Wygenerowane przez tool/gen_widgets.py -->
<LinearLayout {A}
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_background"
    android:orientation="vertical"
    android:padding="12dp">{header()}
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:orientation="horizontal">{names}
    </LinearLayout>{''.join(rows)}
</LinearLayout>
"""


def info(layout, desc, min_w, min_h, cells_w, cells_h):
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!-- Wygenerowane przez tool/gen_widgets.py -->
<appwidget-provider {A}
    android:description="@string/{desc}"
    android:initialLayout="@layout/{layout}"
    android:minWidth="{min_w}dp"
    android:minHeight="{min_h}dp"
    android:minResizeWidth="110dp"
    android:minResizeHeight="60dp"
    android:previewLayout="@layout/{layout}"
    android:resizeMode="horizontal|vertical"
    android:targetCellWidth="{cells_w}"
    android:targetCellHeight="{cells_h}"
    android:updatePeriodMillis="1800000"
    android:widgetCategory="home_screen" />
"""


SHADOW = (
    '<TextView\n'
    '                android:shadowColor="#B3000000"\n'
    '                android:shadowDx="0"\n'
    '                android:shadowDy="1"\n'
    '                android:shadowRadius="3"\n'
)


def with_shadow(xml):
    """Ten sam układ z cieniem pod tekstem: dla jasnego tekstu na przezroczystym tle."""
    return xml.replace("<TextView\n", SHADOW)


for name, build in [("widget_list", list_layout), ("widget_week", week_layout), ("widget_month", month_layout)]:
    xml = build()
    write(RES / "layout" / f"{name}.xml", xml)
    write(RES / "layout" / f"{name}_shadow.xml", with_shadow(xml))

write(RES / "xml" / "widget_agenda_info.xml", info("widget_list", "widget_agenda_desc", 250, 110, 4, 2))
write(RES / "xml" / "widget_day_info.xml", info("widget_list", "widget_day_desc", 180, 110, 3, 2))
write(RES / "xml" / "widget_week_info.xml", info("widget_week", "widget_week_desc", 250, 110, 4, 2))
write(RES / "xml" / "widget_month_info.xml", info("widget_month", "widget_month_desc", 250, 250, 4, 3))

write(RES / "values" / "widget_strings.xml", """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="widget_agenda_name">Najbliższe</string>
    <string name="widget_agenda_desc">Najbliższe wpisy z kalendarza</string>
    <string name="widget_day_name">Dziś</string>
    <string name="widget_day_desc">Dzisiejsze wpisy</string>
    <string name="widget_week_name">Tydzień</string>
    <string name="widget_week_desc">Bieżący tydzień w siedmiu kolumnach</string>
    <string name="widget_month_name">Miesiąc</string>
    <string name="widget_month_desc">Siatka miesiąca z kolorami kategorii</string>
</resources>
""")

colors = {
    "values": dict(bg="#FFFFFF", bg_75="#BFFFFFFF", bg_50="#80FFFFFF",
                   fg="#171B2B", fg2="#5A6378", accent="#3454D1", on_accent="#FFFFFF"),
    "values-night": dict(bg="#1A1F2F", bg_75="#BF1A1F2F", bg_50="#801A1F2F",
                         fg="#ECEFF8", fg2="#9CA5BC", accent="#93A5FF", on_accent="#0E1330"),
}
for folder, c in colors.items():
    body = "".join(f'    <color name="widget_{k}">{v}</color>\n' for k, v in c.items())
    write(RES / folder / "widget_colors.xml", f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n{body}</resources>\n')

for suffix in ["", "_75", "_50"]:
    write(RES / "drawable" / f"widget_background{suffix}.xml", f"""<?xml version="1.0" encoding="utf-8"?>
<shape {A} android:shape="rectangle">
    <solid android:color="@color/widget_bg{suffix}" />
    <corners android:radius="24dp" />
</shape>
""")
write(RES / "drawable" / "widget_today.xml", f"""<?xml version="1.0" encoding="utf-8"?>
<shape {A} android:shape="oval">
    <solid android:color="@color/widget_accent" />
</shape>
""")


def ids(name, fmt, *ranges):
    import itertools
    combos = list(itertools.product(*[range(n) for n in ranges]))
    refs = ", ".join("R.id." + fmt.format(*c) for c in combos)
    return f"    val {name} = intArrayOf({refs})\n"


kt = "// Wygenerowane przez tool/gen_widgets.py\npackage com.kachaj96.kalendarz.widgets\n\nimport com.kachaj96.kalendarz.R\n\nobject WidgetIds {\n"
kt += f"    const val LIST_ROWS = {LIST_ROWS}\n    const val WEEK_BARS = {WEEK_BARS}\n    const val MONTH_ROWS = {MONTH_ROWS}\n"
for field in ["", "_time", "_bar", "_title", "_sub"]:
    kt += ids("row" + field.replace("_", "").capitalize(), "row_{}" + field, LIST_ROWS)
kt += ids("weekCol", "wk_{}", 7)
kt += ids("weekName", "wk_{}_name", 7)
kt += ids("weekNum", "wk_{}_num", 7)
kt += ids("weekMore", "wk_{}_more", 7)
kt += ids("weekBar", "wk_{}_bar_{}", 7, WEEK_BARS)
kt += ids("monthHeader", "mh_{}", 7)
kt += ids("monthRow", "mr_{}", MONTH_ROWS)
kt += ids("monthCell", "mc_{}_{}", MONTH_ROWS, 7)
kt += ids("monthNum", "mn_{}_{}", MONTH_ROWS, 7)
kt += ids("monthDots", "md_{}_{}", MONTH_ROWS, 7)
kt += "}\n"
write(KT / "WidgetIds.kt", kt)
print("gotowe")

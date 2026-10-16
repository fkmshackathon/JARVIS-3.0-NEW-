"""Writes the SYNCHRO launcher and PWA icons from one geometry.

The mark is the same 2x2 period grid the in-app `SynchroMark` draws, so the phone
launcher, the installed PWA and the splash cannot drift into three different brands.
Run it after changing the mark:

    python tools/make_launcher_icons.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android" / "app" / "src" / "main" / "res"
ANDROID = "http://schemas.android.com/apk/res/android"

NAVY = "#0D2B60"
CREAM = "#FFF0C7"
ORANGE = "#FF8A32"

# Adaptive canvases are 108dp and the launcher guarantees only the middle 66dp,
# so the mark spans 44dp centred on 54 — corner distance 28dp, still inside.
CANVAS = 108.0
SPAN = 44.0
CELL = 20.0
RADIUS = 5.0
PLATE_CORNER = 22.0


def _grid() -> list[tuple[float, float, str]]:
    """The four period cells, lower-left painted orange exactly as in the app mark."""
    inset = (CANVAS - SPAN) / 2
    step = SPAN / 2
    return [
        (inset + column * step, inset + row * step, ORANGE if (row, column) == (1, 0) else CREAM)
        for row in range(2)
        for column in range(2)
    ]


def _rgb(hex_colour: str) -> tuple[int, int, int]:
    return (int(hex_colour[1:3], 16), int(hex_colour[3:5], 16), int(hex_colour[5:7], 16))


def _rounded_rect(x: float, y: float, size: float, radius: float) -> str:
    right, bottom = x + size, y + size
    arc = f"{radius:.2f},{radius:.2f} 0 0 1"
    return (
        f"M{x + radius:.2f},{y:.2f}H{right - radius:.2f}A{arc} {right:.2f},{y + radius:.2f}"
        f"V{bottom - radius:.2f}A{arc} {right - radius:.2f},{bottom:.2f}"
        f"H{x + radius:.2f}A{arc} {x:.2f},{bottom - radius:.2f}"
        f"V{y + radius:.2f}A{arc} {x + radius:.2f},{y:.2f}Z"
    )


def _plate(px: int, *, bleed: bool) -> Image.Image:
    """Navy plate carrying the grid. `bleed` fills the square for maskable icons,
    which the browser crops itself — rounding there would show as a halo."""
    scale = px / CANVAS
    sheet = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    plate = Image.new("RGBA", (px, px), (*_rgb(NAVY), 255))
    if bleed:
        sheet.paste(plate, (0, 0))
    else:
        mask = Image.new("L", (px, px), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, px - 1, px - 1], radius=PLATE_CORNER * scale, fill=255
        )
        sheet.paste(plate, (0, 0), mask)

    draw = ImageDraw.Draw(sheet)
    for x, y, colour in _grid():
        draw.rounded_rectangle(
            [x * scale, y * scale, (x + CELL) * scale, (y + CELL) * scale],
            radius=RADIUS * scale,
            fill=(*_rgb(colour), 255),
        )
    return sheet


def _save_xml(text: str, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('<?xml version="1.0" encoding="utf-8"?>\n' + text, encoding="utf-8")
    print(path.relative_to(ROOT))


def write_adaptive() -> None:
    paths = "".join(
        f'\n    <path android:fillColor="{colour}"'
        f' android:pathData="{_rounded_rect(x, y, CELL, RADIUS)}" />'
        for x, y, colour in _grid()
    )
    _save_xml(
        f'<vector xmlns:android="{ANDROID}"\n'
        f'        android:width="108dp" android:height="108dp"\n'
        f'        android:viewportWidth="108" android:viewportHeight="108">{paths}\n</vector>\n',
        RES / "drawable" / "ic_launcher_foreground.xml",
    )
    _save_xml(
        f'<resources>\n    <color name="ic_launcher_background">{NAVY}</color>\n</resources>\n',
        RES / "values" / "ic_launcher_background.xml",
    )
    _save_xml(
        f'<adaptive-icon xmlns:android="{ANDROID}">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@drawable/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n",
        RES / "mipmap-anydpi-v26" / "ic_launcher.xml",
    )


def write_android_legacy() -> None:
    """Density fallbacks for the pre-API-26 launchers still running in college labs."""
    source = _plate(int(CANVAS * 4), bleed=False)
    for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        source.resize((px, px), Image.LANCZOS).save(folder / "ic_launcher.png")
        print(f"mipmap-{name} {px}px")


def write_web() -> None:
    icons = ROOT / "web" / "icons"
    icons.mkdir(parents=True, exist_ok=True)
    rounded = _plate(512, bleed=False)
    rounded.resize((192, 192), Image.LANCZOS).save(icons / "Icon-192.png")
    rounded.save(icons / "Icon-512.png")
    _plate(192, bleed=True).save(icons / "Icon-maskable-192.png")
    _plate(512, bleed=True).save(icons / "Icon-maskable-512.png")
    rounded.resize((64, 64), Image.LANCZOS).save(ROOT / "web" / "favicon.png")
    print("web/icons + favicon.png")


def main() -> None:
    write_adaptive()
    write_android_legacy()
    write_web()


if __name__ == "__main__":
    main()

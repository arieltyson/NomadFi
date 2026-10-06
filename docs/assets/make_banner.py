#!/usr/bin/env python3
"""Builds docs/assets/banner.png, the README header.

The app icon is composited from its Icon Composer source
(NomadFi/NomadFi/NomadFi.icon), so the banner follows the icon if it
changes. Rendered at 2x (2000 x 1000) and shown at 1000 x 500.

Run from the repository root:  python3 docs/assets/make_banner.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ICON = ROOT / "NomadFi/NomadFi/NomadFi.icon"
OUT = ROOT / "docs/assets/banner.png"

SCALE = 2
WIDTH, HEIGHT = 1000 * SCALE, 500 * SCALE

BACKGROUND = (0x06, 0x11, 0x0F)
WORDMARK = (0xF2, 0xF5, 0xF4)
SLOGAN = (0x9D, 0xB3, 0xAE)
FOOTNOTE = (0x6E, 0x82, 0x7D)
RULE = (0x1E, 0x2E, 0x2A)
TEAL = (0x33, 0xD4, 0xB5)  # BrandSecondary, dark appearance
DIM = (0x2A, 0x3D, 0x39)

ICON_TOP, ICON_BOTTOM = (0x00, 0x4D, 0x4D), (0x00, 0x6B, 0x5A)  # icon.json fill

SERIF = "/System/Library/Fonts/NewYork.ttf"
SANS = "/System/Library/Fonts/SFNS.ttf"
MONO = "/System/Library/Fonts/SFNSMono.ttf"

# The person's own currencies glow; the rest of the world waits.
CURRENCIES = ["EUR", "GBP", "CAD", "JPY", "INR", "TTD", "NGN", "MXN", "USD", "AUD", "KES", "BRL"]
LIT = {"CAD", "TTD", "USD"}


def px(value: float) -> int:
    return round(value * SCALE)


def font(path: str, size: float, weight: str | None = None) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(path, px(size))
    if weight:
        face.set_variation_by_name(weight)
    return face


def app_icon(size: int) -> Image.Image:
    side = 1024
    fill = Image.new("RGBA", (side, side))
    draw = ImageDraw.Draw(fill)
    for y in range(side):
        t = min(y / (0.7 * side), 1)
        draw.line([(0, y), (side, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(ICON_TOP, ICON_BOTTOM)))
    for layer in sorted((ICON / "Assets").glob("*.png")):
        fill.alpha_composite(Image.open(layer).convert("RGBA"))
    icon = fill.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([(0, 0), (size, size)], radius=round(size * 0.225), fill=255)
    icon.putalpha(mask)
    return icon


def main() -> None:
    canvas = Image.new("RGB", (WIDTH, HEIGHT), BACKGROUND)
    draw = ImageDraw.Draw(canvas)

    # Mark, wordmark and slogan.
    icon_size = px(140)
    canvas.paste(app_icon(icon_size), (px(96), px(100)), app_icon(icon_size))
    draw.text((px(270), px(118)), "NomadFi", font=font(SERIF, 84), fill=WORDMARK)
    draw.text((px(274), px(212)), "Wealth without borders.", font=font(SANS, 22, "Regular"), fill=SLOGAN)

    # Currency motif: one pill per code, lit for the person's own.
    left, right, top, pill_height = px(96), px(904), px(318), px(40)
    gap = px(10)
    pill_width = (right - left - gap * (len(CURRENCIES) - 1)) / len(CURRENCIES)
    code_font = font(MONO, 15)
    for index, code in enumerate(CURRENCIES):
        x = left + index * (pill_width + gap)
        lit = code in LIT
        draw.rounded_rectangle(
            [(x, top), (x + pill_width, top + pill_height)],
            radius=pill_height / 2,
            fill=TEAL if lit else DIM,
        )
        draw.text(
            (x + pill_width / 2, top + pill_height / 2), code, font=code_font,
            fill=BACKGROUND if lit else FOOTNOTE, anchor="mm",
        )

    # Rule and footnotes.
    draw.line([(left, px(388)), (right, px(388))], fill=RULE, width=px(1))
    note = font(SANS, 16, "Regular")
    draw.text((left, px(410)), "one net worth across every country", font=note, fill=FOOTNOTE)
    draw.text((right, px(410)), "on your iPhone, never sold", font=note, fill=FOOTNOTE, anchor="ra")

    canvas.save(OUT, optimize=True)
    print(OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()

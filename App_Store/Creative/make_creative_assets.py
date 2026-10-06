#!/usr/bin/env python3
"""Builds NomadFi's App Store creative assets.

    header.png          3840 x 1646  Product page header
    search-results.png  3840 x 2560  Search results asset

Layout follows Apple's official templates (developer.apple.com/app-store/
asset-best-practices): everything that must be seen sits inside the "Art
Safe Area" each template marks; the rest is atmosphere that devices may
crop and the App Store may overlay.

    Header art safe area:          x 1097-2743, y  493-1154
    Search results art safe area:  x  836-3004, y  765-1795

The mark is composited from the app icon's Icon Composer source; the
country cards are cut from the real Dashboard capture in
../Screenshots/raw. Output is opaque RGB PNG.

Run from this folder:  python3 make_creative_assets.py   (needs Pillow)
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).parent
ROOT = HERE.parents[1]
ICON_LAYERS = ROOT / "NomadFi/NomadFi/NomadFi.icon/Assets"
DASHBOARD = HERE.parent / "Screenshots/raw/01-dashboard.png"

SERIF = "/System/Library/Fonts/NewYork.ttf"
SANS = "/System/Library/Fonts/SFNS.ttf"

# Brand palette.
DEEP = (0x06, 0x11, 0x0F)       # near black
GLOW = (0x0B, 0x5C, 0x4F)       # brand teal, deepened
LINE = (0x33, 0xD4, 0xB5)       # BrandSecondary (dark)
WHITE = (0xFF, 0xFF, 0xFF)
SUBTITLE = (0x33, 0xD4, 0xB5)   # 7.3:1 on the deep field

HEADER_SIZE = (3840, 1646)
HEADER_SAFE = (1097, 493, 2743, 1154)
SEARCH_SIZE = (3840, 2560)
SEARCH_SAFE = (836, 765, 3004, 1795)

# The three Dashboard country cards in the 1320 x 2868 capture.
CARD_BOUNDS = [(48, 951, 1272, 1229), (48, 1265, 1272, 1543), (48, 1579, 1272, 1857)]
CARD_RADIUS = 48  # RadiusTokens.card (16pt) at 3x


def font(path: str, size: int, weight: str | None = None) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(path, size)
    if weight:
        face.set_variation_by_name(weight)
    return face


def field(size: tuple[int, int]) -> Image.Image:
    """The deep brand field: a soft teal glow over near black, and a
    faint wireframe globe that runs off every edge."""
    width, height = size
    canvas = Image.new("RGB", size, DEEP)

    glow = Image.new("L", size, 0)
    ImageDraw.Draw(glow).ellipse(
        [width * 0.18, height * 0.05, width * 0.82, height * 0.95], fill=255
    )
    glow = glow.filter(ImageFilter.GaussianBlur(min(size) * 0.28))
    canvas = Image.composite(Image.new("RGB", size, GLOW), canvas, glow)

    lines = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(lines)
    cx, cy = width / 2, height / 2
    radius = max(size) * 0.42
    stroke = max(3, round(min(size) / 400))
    color = (*LINE, 34)
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], outline=color, width=stroke)
    for step in range(1, 6):  # meridians
        half = radius * math.cos(step * math.pi / 12)
        draw.ellipse([cx - half, cy - radius, cx + half, cy + radius], outline=color, width=stroke)
    for step in range(-4, 5):  # parallels
        y = cy + radius * math.sin(step * math.pi / 10)
        half = math.sqrt(max(radius**2 - (y - cy) ** 2, 0))
        draw.line([(cx - half, y), (cx + half, y)], fill=color, width=stroke)
    canvas.paste(lines, (0, 0), lines)
    return canvas


def mark(size: int) -> Image.Image:
    """The white globe-and-compass from the app icon, without its tile."""
    glyph = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    for layer in sorted(ICON_LAYERS.glob("*.png")):
        glyph.alpha_composite(Image.open(layer).convert("RGBA"))
    glyph = glyph.crop(glyph.getbbox())
    glyph.thumbnail((size, size), Image.LANCZOS)
    return glyph


def centered_text(draw, text, face, center_x, top, fill) -> int:
    draw.text((center_x, top), text, font=face, fill=fill, anchor="mt")
    box = draw.textbbox((center_x, top), text, font=face, anchor="mt")
    return box[3]


def rounded(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([(0, 0), image.size], radius=radius, fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def header() -> Image.Image:
    canvas = field(HEADER_SIZE)
    left, top, right, bottom = HEADER_SAFE
    center_x = (left + right) / 2

    glyph = mark(330)
    glyph_top = top + 30
    canvas.paste(glyph, (round(center_x - glyph.width / 2), glyph_top), glyph)

    draw = ImageDraw.Draw(canvas)
    slogan_bottom = centered_text(
        draw, "Wealth without borders.", font(SERIF, 104), center_x, glyph_top + glyph.height + 70, WHITE
    )
    assert slogan_bottom <= bottom, "slogan leaves the header safe area"
    return canvas


def search_results() -> Image.Image:
    canvas = field(SEARCH_SIZE)
    left, top, right, bottom = SEARCH_SAFE

    # Real country cards, at their captured resolution, stacked on the right.
    capture = Image.open(DASHBOARD).convert("RGB")
    cards = [rounded(capture.crop(box), CARD_RADIUS) for box in CARD_BOUNDS]
    gap = 34
    stack_height = sum(card.height for card in cards) + gap * (len(cards) - 1)
    card_x = right - cards[0].width
    y = top + (bottom - top - stack_height) // 2

    shadow = Image.new("L", SEARCH_SIZE, 0)
    shadow_draw = ImageDraw.Draw(shadow)
    for card in cards:
        shadow_draw.rounded_rectangle(
            [card_x, y + 24, card_x + card.width, y + 24 + card.height], radius=CARD_RADIUS, fill=150
        )
        y += card.height + gap
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas = Image.composite(Image.new("RGB", SEARCH_SIZE, DEEP), canvas, shadow)

    y = top + (bottom - top - stack_height) // 2
    for card in cards:
        canvas.paste(card, (card_x, y), card)
        y += card.height + gap

    # Headline on the left, vertically centred in the safe area.
    draw = ImageDraw.Draw(canvas)
    title = font(SANS, 132, "Bold")
    subtitle = font(SANS, 58, "Regular")
    line_height = 150
    lines = ["Every country.", "One net worth."]
    block_height = line_height * len(lines) + 48 + 70
    text_top = top + (bottom - top - block_height) // 2
    for index, line in enumerate(lines):
        draw.text((left, text_top + index * line_height), line, font=title, fill=WHITE)
    draw.text(
        (left, text_top + line_height * len(lines) + 48),
        "Every account, in every currency.", font=subtitle, fill=SUBTITLE,
    )
    widest = max(draw.textlength(line, font=title) for line in lines)
    assert left + widest < card_x - 60, "headline runs into the cards"
    return canvas


def main() -> None:
    for name, image in (("header.png", header()), ("search-results.png", search_results())):
        image.convert("RGB").save(HERE / name, optimize=True)
        print(name, image.size)


if __name__ == "__main__":
    main()

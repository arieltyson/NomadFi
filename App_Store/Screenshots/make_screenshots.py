#!/usr/bin/env python3
"""Builds NomadFi's App Store listing screenshots from the raw captures.

Each raw capture in raw/ (taken by AppStoreScreenshotTests on an iPhone
17 Pro Max simulator) is placed on the brand gradient under its title and
subtitle, then written at both iPhone sizes App Store Connect accepts:

    6.9-inch/  1320 x 2868
    6.5-inch/  1284 x 2778

Output is opaque RGB PNG — App Store Connect rejects alpha channels.

Run from this folder:  python3 make_screenshots.py   (needs Pillow)
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
FONT = "/System/Library/Fonts/SFNS.ttf"  # SF Pro, variable

# Brand palette (NomadFi asset catalog).
BACKGROUND_TOP = (0x00, 0x35, 0x2D)     # dark brand base
BACKGROUND_BOTTOM = (0x06, 0x11, 0x0F)  # near black
TITLE = (0xFF, 0xFF, 0xFF)              # 13.6:1 on the base
SUBTITLE = (0x33, 0xD4, 0xB5)           # BrandSecondary (dark), 7.3:1 on the base

# Points at @3x: title 36pt / 40pt line, subtitle 20pt / 24pt line.
SCALE = 3
TITLE_SIZE, TITLE_LINE = 36 * SCALE, 40 * SCALE
SUBTITLE_SIZE, SUBTITLE_LINE = 20 * SCALE, 24 * SCALE

SCREENS = [
    ("01-dashboard", "Every country.\nOne net worth.", "Every account, in every currency."),
    ("02-country", "Tap a country.\nSee it all.", "Accounts and spending, by country."),
    ("03-decisions", "Decide before\nyou spend.", "Card and credit checks before you buy."),
    ("04-exchange-rates", "Rates without\nthe guesswork.", "Every pair between your currencies."),
    ("05-tax-vault", "Receipts ready\nfor tax season.", "Scanned on your iPhone. Nothing uploads."),
]

# No line may span more than this share of the canvas.
MAX_TEXT_WIDTH = 0.88

SIZES = {"6.9-inch": (1320, 2868), "6.5-inch": (1284, 2778)}


def font(size: int, weight: str) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(FONT, size)
    face.set_variation_by_name(weight)
    return face


def gradient(size: tuple[int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / (height - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(BACKGROUND_TOP, BACKGROUND_BOTTOM))
        draw.line([(0, y), (width, y)], fill=color)
    return image


def centered_lines(draw, lines, face, line_height, top, width, fill) -> int:
    """Draws each line centred; returns the y below the block."""
    for index, line in enumerate(lines):
        if draw.textlength(line, font=face) > width * MAX_TEXT_WIDTH:
            raise ValueError(f"Too wide for the canvas: {line!r}")
        y = top + index * line_height
        draw.text((width / 2, y + line_height / 2), line, font=face, fill=fill, anchor="mm")
    return top + len(lines) * line_height


def compose(raw: Image.Image, title: str, subtitle: str, size: tuple[int, int]) -> Image.Image:
    width, height = size
    canvas = gradient(size)
    draw = ImageDraw.Draw(canvas)

    # Proportions are relative to the 1284-wide canvas.
    unit = width / 1284
    y = round(150 * unit)
    y = centered_lines(draw, title.split("\n"), font(round(TITLE_SIZE * unit), "Bold"),
                       round(TITLE_LINE * unit), y, width, TITLE)
    y += round(30 * unit)
    y = centered_lines(draw, [subtitle], font(round(SUBTITLE_SIZE * unit), "Regular"),
                       round(SUBTITLE_LINE * unit), y, width, SUBTITLE)

    # The screen, scaled to leave an even margin, with display-like corners.
    top = y + round(70 * unit)
    bottom_margin = round(90 * unit)
    screen_height = height - top - bottom_margin
    screen_width = round(raw.width * screen_height / raw.height)
    screen = raw.convert("RGB").resize((screen_width, screen_height), Image.LANCZOS)

    radius = round(screen_width * 0.11)
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([(0, 0), screen.size], radius=radius, fill=255)
    canvas.paste(screen, ((width - screen_width) // 2, top), mask)
    return canvas


def main() -> None:
    for folder, size in SIZES.items():
        out = HERE / folder
        out.mkdir(exist_ok=True)
        for name, title, subtitle in SCREENS:
            raw = Image.open(HERE / "raw" / f"{name}.png")
            compose(raw, title, subtitle, size).save(out / f"{name}.png", optimize=True)
            print(f"{folder}/{name}.png")


if __name__ == "__main__":
    main()

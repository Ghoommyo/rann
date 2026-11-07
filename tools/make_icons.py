"""Makes every icon the game uses from the two pictures in assets/icons/source/.

    pip install pillow numpy scipy
    python3 tools/make_icons.py

Sources (AI image generators paint a fake "transparent" checkerboard into the
picture, so the background is cut out here):
  rann.png         the emblem (fighter in a ring of fire), any square size
  other_icons.png  a 5x2 sheet of UI icons with labels under each; the labels
                   are cut off

Makes:
  assets/icons/app/emblem.png      the emblem alone, transparent (menus, boot)
  assets/icons/app/icon.png        app icon: emblem on the game's background (iOS, web, window)
  assets/icons/app/icon_192.png    Android launcher icon (older phones)
  assets/icons/app/adaptive_*.png  Android adaptive icon layers (432x432)
  assets/icons/ui/<name>.png       one 128x128 icon per sheet cell
  server/admin/icon.png            the admin portal's browser-tab icon
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/icons/source"
APP = ROOT / "assets/icons/app"
UI = ROOT / "assets/icons/ui"

# The menu background's colours (MenuStyle.BG_TOP / BG_BOTTOM).
BG_TOP = (20, 15, 36)
BG_BOTTOM = (89, 31, 26)

# Sheet cells, left to right, top to bottom.
UI_NAMES = [
    "versus_cpu", "local_versus", "online", "training", "settings",
    "profile", "leaderboard", "locked", "menu", "logout",
]
UI_SIZE = 128


def cut_out(rgb: np.ndarray, background: np.ndarray, lo: float, hi: float) -> np.ndarray:
    """RGBA from RGB and a mask of definite background pixels. Pixels at the
    edge are made partly transparent, with the background colour taken back
    out of them, so there's no grey fringe."""
    h, w, _ = rgb.shape
    alpha = np.where(background, 0.0, 1.0)
    # The background colour near each pixel, spread a few pixels inwards.
    bg_sum = np.where(background[..., None], rgb, 0.0)
    bg_count = background.astype(float)
    known = background.copy()
    for _ in range(3):
        grown_sum = ndimage.uniform_filter(bg_sum, size=(3, 3, 1)) * 9
        grown_count = ndimage.uniform_filter(bg_count, size=3) * 9
        new = ~known & (grown_count > 0)
        bg_sum[new] = grown_sum[new] / grown_count[new, None]
        bg_count[new] = 1.0
        known |= new
    edge = known & ~background
    bg = bg_sum[edge]
    difference = np.abs(rgb[edge] - bg).max(axis=1)
    a = np.clip((difference - lo) / (hi - lo), 0.0, 1.0)
    alpha[edge] = a
    out = rgb.copy()
    safe = np.maximum(a, 1e-3)[:, None]
    out[edge] = np.clip(bg + (rgb[edge] - bg) / safe, 0, 255)
    return np.dstack([out, alpha * 255]).astype(np.uint8)


def trim_square(image: Image.Image, margin: float = 0.0) -> Image.Image:
    """Crops to what's visible, then pads to a centred square."""
    box = image.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    image = image.crop(box)
    side = int(max(image.size) * (1 + 2 * margin))
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(image, ((side - image.width) // 2, (side - image.height) // 2))
    return square


def gradient(size: int) -> Image.Image:
    t = np.linspace(0, 1, size)[:, None, None]
    rows = np.array(BG_TOP) * (1 - t) + np.array(BG_BOTTOM) * t
    pixels = np.repeat(rows, size, axis=1)
    # A warm glow behind the emblem.
    y, x = np.mgrid[0:size, 0:size] / size - 0.5
    glow = np.clip(1 - np.sqrt(x * x + y * y) / 0.5, 0, 1)[..., None] ** 2
    pixels = pixels + glow * np.array([120, 45, 10]) * 0.6
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).convert("RGBA")


def place(canvas: Image.Image, art: Image.Image, fraction: float) -> Image.Image:
    """`art` scaled to `fraction` of the canvas, centred on it."""
    side = int(canvas.width * fraction)
    art = art.resize((side, side), Image.LANCZOS)
    out = canvas.copy()
    offset = (canvas.width - side) // 2
    out.alpha_composite(art, (offset, offset))
    return out


def make_app_icons() -> None:
    rgb = np.asarray(Image.open(SOURCE / "rann.png").convert("RGB")).astype(float)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    # The light grey/white checkerboard: colourless and bright.
    background = (chroma < 16) & (rgb.min(axis=2) > 175)
    background = ndimage.binary_opening(background, iterations=1)
    emblem = trim_square(Image.fromarray(cut_out(rgb, background, lo=14, hi=90)), margin=0.02)
    emblem = emblem.resize((1024, 1024), Image.LANCZOS)

    APP.mkdir(parents=True, exist_ok=True)
    emblem.save(APP / "emblem.png")
    icon = place(gradient(1024), emblem, 0.86)
    icon.convert("RGB").save(APP / "icon.png")  # iOS refuses icons with transparency
    icon.resize((192, 192), Image.LANCZOS).convert("RGB").save(APP / "icon_192.png")
    # Android adaptive icon: the phone crops the layers to a circle, squircle...
    # Everything important stays inside the middle 66 of 108 dp.
    place(Image.new("RGBA", (432, 432), (0, 0, 0, 0)), emblem, 0.6).save(APP / "adaptive_foreground.png")
    gradient(432).convert("RGB").save(APP / "adaptive_background.png")
    silhouette = np.asarray(emblem).copy()
    silhouette[..., :3] = 255
    place(Image.new("RGBA", (432, 432), (0, 0, 0, 0)), Image.fromarray(silhouette), 0.6).save(APP / "adaptive_monochrome.png")
    icon.resize((128, 128), Image.LANCZOS).convert("RGB").save(ROOT / "server/admin/icon.png")
    print("app icons ->", APP.relative_to(ROOT))


def make_ui_icons() -> None:
    sheet = np.asarray(Image.open(SOURCE / "other_icons.png").convert("RGB")).astype(float)
    chroma = sheet.max(axis=2) - sheet.min(axis=2)
    # The dark checkerboard, and the faint grey sparkle watermark on it.
    background = (chroma < 28) & (sheet.max(axis=2) < 190)
    rgba = cut_out(sheet, background, lo=20, hi=110)
    h, w, _ = rgba.shape
    UI.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(UI_NAMES):
        row, col = divmod(index, 5)
        x0, x1 = round(col * w / 5), round((col + 1) * w / 5)
        y0, y1 = round(row * h / 2), round((row + 1) * h / 2)
        cell = rgba[y0:y1, x0:x1].copy()
        solid = cell[..., 3] > 128
        # The icon is the top block of rows; the label under it is cut off.
        rows = np.flatnonzero(solid.sum(axis=1) > 2)
        blocks = np.split(rows, np.flatnonzero(np.diff(rows) > 12) + 1)
        icon_rows = max((b for b in blocks if len(b)), key=lambda b: (len(b) > 60, -b[0]))
        cell[: icon_rows[0]] = 0
        cell[icon_rows[-1] + 1 :] = 0
        # Drop specks (left-over watermark or checkerboard).
        labels, count = ndimage.label(cell[..., 3] > 40)
        sizes = ndimage.sum(np.ones_like(labels), labels, range(1, count + 1))
        for label, size in enumerate(sizes, start=1):
            if size < 150:
                cell[labels == label] = 0
        icon = trim_square(Image.fromarray(cell), margin=0.04)
        icon.resize((UI_SIZE, UI_SIZE), Image.LANCZOS).save(UI / f"{name}.png")
    print("ui icons ->", UI.relative_to(ROOT))


if __name__ == "__main__":
    make_app_icons()
    make_ui_icons()

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ICON_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]
CANVAS_SIZE = 700
DEFAULT_FILL_RATIO = 1.02
DEFAULT_BORDER_RADIUS = 12
DEFAULT_ELEVATION = 32
SOFT_WHITE_BG = (238, 244, 252, 255)
SHADOW_COLOR = (71, 91, 128, 58)


def _rounded_mask(size: int, border_radius: int) -> Image.Image:
    radius = max(0, min(border_radius, size // 2))
    mask_scale = 4
    mask_size = size * mask_scale
    mask = Image.new("L", (mask_size, mask_size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        (0, 0, mask_size - 1, mask_size - 1),
        radius=radius * mask_scale,
        fill=255,
    )
    return mask.resize((size, size), Image.Resampling.LANCZOS)


def _rounded_rect_mask(size: int, rect: tuple[int, int, int, int], border_radius: int) -> Image.Image:
    radius = max(0, min(border_radius, min(rect[2] - rect[0], rect[3] - rect[1]) // 2))
    mask_scale = 4
    mask_size = size * mask_scale
    scaled_rect = tuple(value * mask_scale for value in rect)
    mask = Image.new("L", (mask_size, mask_size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        scaled_rect,
        radius=radius * mask_scale,
        fill=255,
    )
    return mask.resize((size, size), Image.Resampling.LANCZOS)


def _offset_rect(rect: tuple[int, int, int, int], offset_x: int, offset_y: int) -> tuple[int, int, int, int]:
    left, top, right, bottom = rect
    return left + offset_x, top + offset_y, right + offset_x, bottom + offset_y


def _trim_bottom_text(alpha: Image.Image, bbox: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    left, top, right, bottom = bbox
    width = right - left
    height = bottom - top
    search_start = top + int(height * 0.65)
    zero_run = 0

    for y in range(search_start, bottom):
        row_has_alpha = False
        for x in range(left, right):
            if alpha.getpixel((x, y)) > 0:
                row_has_alpha = True
                break
        if row_has_alpha:
            zero_run = 0
            continue

        zero_run += 1
        if zero_run >= 20:
            cropped_bottom = y - zero_run + 1
            if cropped_bottom > top + int(height * 0.6):
                return left, top, right, cropped_bottom

    return bbox


def _build_square_canvas(
    image: Image.Image,
    fill_ratio: float = DEFAULT_FILL_RATIO,
    border_radius: int = DEFAULT_BORDER_RADIUS,
    elevation: int = DEFAULT_ELEVATION,
) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("The source image is fully transparent.")

    bbox = _trim_bottom_text(image.getchannel("A"), bbox)
    cropped = image.crop(bbox)
    cropped_width, cropped_height = cropped.size

    card_inset = max(border_radius, elevation)
    card_rect = (
        card_inset,
        max(border_radius, elevation // 2),
        CANVAS_SIZE - card_inset - 1,
        CANVAS_SIZE - card_inset - max(1, elevation // 4) - 1,
    )
    card_width = card_rect[2] - card_rect[0] + 1
    card_height = card_rect[3] - card_rect[1] + 1

    target_extent = int(min(card_width, card_height) * fill_ratio)
    resize_ratio = target_extent / max(cropped_width, cropped_height)
    resized_width = max(1, round(cropped_width * resize_ratio))
    resized_height = max(1, round(cropped_height * resize_ratio))
    resized = cropped.resize((resized_width, resized_height), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))

    card_mask = _rounded_rect_mask(CANVAS_SIZE, card_rect, border_radius)
    shadow_offset_y = max(1, elevation // 3)
    shadow_rect = _offset_rect(card_rect, 0, shadow_offset_y)
    shadow_mask = _rounded_rect_mask(CANVAS_SIZE, shadow_rect, border_radius)
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(radius=elevation))
    shadow_alpha = shadow_mask.point(lambda alpha: alpha * SHADOW_COLOR[3] // 255)
    shadow = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), SHADOW_COLOR[:3] + (0,))
    shadow.putalpha(shadow_alpha)
    canvas.alpha_composite(shadow)

    card = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    background = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), SOFT_WHITE_BG)
    card.paste(background, (0, 0), card_mask)
    offset_x = card_rect[0] + (card_width - resized_width) // 2
    offset_y = card_rect[1] + (card_height - resized_height) // 2
    card.alpha_composite(resized, (offset_x, offset_y))
    card.putalpha(card_mask)
    canvas.alpha_composite(card)
    return canvas


def _save_windows_icon(square_canvas: Image.Image, icon_output: Path) -> None:
    frames = [square_canvas.resize((size, size), Image.Resampling.LANCZOS) for size in ICON_SIZES]
    frames[-1].save(
        icon_output,
        format="ICO",
        append_images=frames[:-1],
        sizes=[(size, size) for size in ICON_SIZES],
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a Windows ICO from a PNG logo.")
    parser.add_argument("source", type=Path)
    parser.add_argument("icon_output", type=Path)
    parser.add_argument("--preview-output", type=Path)
    parser.add_argument("--fill-ratio", type=float, default=DEFAULT_FILL_RATIO)
    parser.add_argument("--border-radius", type=int, default=DEFAULT_BORDER_RADIUS)
    parser.add_argument("--elevation", type=int, default=DEFAULT_ELEVATION)
    args = parser.parse_args()

    source_image = Image.open(args.source).convert("RGBA")
    square_canvas = _build_square_canvas(
        source_image,
        fill_ratio=args.fill_ratio,
        border_radius=args.border_radius,
        elevation=args.elevation,
    )

    args.icon_output.parent.mkdir(parents=True, exist_ok=True)
    _save_windows_icon(square_canvas, args.icon_output)

    if args.preview_output is not None:
        args.preview_output.parent.mkdir(parents=True, exist_ok=True)
        preview = square_canvas.resize((700, 700), Image.Resampling.LANCZOS)
        preview.save(args.preview_output, format="PNG")


if __name__ == "__main__":
    main()

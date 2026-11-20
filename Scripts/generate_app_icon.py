#!/usr/bin/env python3
"""Generate crisp 4x-supersampled Swiss Editorial App Icon for PureScan (配料照妖镜)."""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = ROOT / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
ICON_DIR.mkdir(parents=True, exist_ok=True)


def draw_icon() -> Image.Image:
    S = 2048  # 2x supersample -> downscale LANCZOS to 1024
    img = Image.new("RGBA", (S, S), (20, 21, 20, 255))
    draw = ImageDraw.Draw(img)

    # Subtle radial charcoal studio vignette
    for r in range(S, 0, -32):
        ratio = r / S
        shade = int(18 + 20 * (1.0 - ratio))
        draw.ellipse([S // 2 - r, S // 2 - r, S // 2 + r, S // 2 + r], fill=(shade, shade + 1, shade, 255))

    # Central warm archival ingredient receipt card
    card_margin_x = 340
    card_top = 290
    card_bottom = S - 290
    draw.rounded_rectangle(
        [card_margin_x, card_top, S - card_margin_x, card_bottom],
        radius=110,
        fill=(248, 246, 238, 255),
        outline=(230, 224, 212, 255),
        width=8,
    )

    # Ingredient label bars inside card (clean top, highlighted red danger bars, clean bottom)
    ink = (34, 34, 32, 255)
    soft_ink = (176, 172, 162, 255)
    red = (220, 38, 38, 255)
    red_soft = (254, 226, 226, 255)
    green = (17, 138, 84, 255)

    # Header bar inside receipt
    draw.rounded_rectangle([460, 420, 960, 476], radius=28, fill=ink)
    draw.rounded_rectangle([460, 520, 1280, 558], radius=19, fill=soft_ink)

    # Row 1: Clean green check line
    draw.ellipse([460, 650, 536, 726], fill=green)
    draw.rounded_rectangle([576, 662, 1380, 714], radius=26, fill=(215, 240, 226, 255))
    draw.rounded_rectangle([596, 678, 1180, 698], radius=10, fill=green)

    # Row 2: RED FLAG additive bar (caught by the scanner laser!)
    draw.rounded_rectangle([440, 825, S - 440, 1020], radius=40, fill=red_soft, outline=red, width=10)
    draw.ellipse([486, 878, 578, 970], fill=red)
    # White exclamation mark inside red dot
    draw.rounded_rectangle([522, 895, 542, 934], radius=8, fill=(255, 255, 255, 255))
    draw.ellipse([522, 944, 542, 962], fill=(255, 255, 255, 255))
    draw.rounded_rectangle([618, 888, 1420, 926], radius=19, fill=red)
    draw.rounded_rectangle([618, 946, 1160, 974], radius=14, fill=(235, 112, 112, 255))

    # Row 3: Lower clean bars
    draw.rounded_rectangle([460, 1130, 1340, 1172], radius=21, fill=soft_ink)
    draw.rounded_rectangle([460, 1230, 1140, 1272], radius=21, fill=soft_ink)
    draw.rounded_rectangle([460, 1330, 1250, 1372], radius=21, fill=soft_ink)

    # Bottom clean green verification badge (overlapping bottom-right corner)
    badge_cx, badge_cy, badge_r = 1480, 1460, 250
    draw.ellipse(
        [badge_cx - badge_r - 20, badge_cy - badge_r - 20, badge_cx + badge_r + 20, badge_cy + badge_r + 20],
        fill=(20, 21, 20, 255),
    )
    draw.ellipse(
        [badge_cx - badge_r, badge_cy - badge_r, badge_cx + badge_r, badge_cy + badge_r],
        fill=green,
    )
    # Crisp checkmark inside emerald seal
    draw.line(
        [(badge_cx - 100, badge_cy + 10), (badge_cx - 25, badge_cy + 85), (badge_cx + 110, badge_cy - 75)],
        fill=(255, 255, 255, 255),
        width=48,
        joint="curve",
    )

    # Glowing red scanner laser beam across middle
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.rounded_rectangle([190, 900, S - 190, 948], radius=24, fill=(239, 68, 68, 220))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=34))
    img = Image.alpha_composite(img, glow)

    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([200, 912, S - 200, 936], radius=12, fill=(255, 78, 78, 255))

    # Crisp 4 viewfinder corner brackets (vermilion red)
    b_pad = 175
    b_len = 240
    b_w = 46
    bracket_color = (239, 68, 68, 255)
    # Top-left
    draw.rounded_rectangle([b_pad, b_pad, b_pad + b_len, b_pad + b_w], radius=20, fill=bracket_color)
    draw.rounded_rectangle([b_pad, b_pad, b_pad + b_w, b_pad + b_len], radius=20, fill=bracket_color)
    # Top-right
    draw.rounded_rectangle([S - b_pad - b_len, b_pad, S - b_pad, b_pad + b_w], radius=20, fill=bracket_color)
    draw.rounded_rectangle([S - b_pad - b_w, b_pad, S - b_pad, b_pad + b_len], radius=20, fill=bracket_color)
    # Bottom-left
    draw.rounded_rectangle([b_pad, S - b_pad - b_w, b_pad + b_len, S - b_pad], radius=20, fill=bracket_color)
    draw.rounded_rectangle([b_pad, S - b_pad - b_len, b_pad + b_w, S - b_pad], radius=20, fill=bracket_color)

    out = img.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
    return out


def main() -> None:
    icon = draw_icon()
    icon_path = ICON_DIR / "AppIcon-1024.png"
    icon.save(icon_path, "PNG")

    contents = {
        "images": [
            {
                "filename": "AppIcon-1024.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (ICON_DIR / "Contents.json").write_text(json.dumps(contents, indent=2), encoding="utf-8")
    print(f"Generated {icon_path} ({icon.size})")


if __name__ == "__main__":
    main()

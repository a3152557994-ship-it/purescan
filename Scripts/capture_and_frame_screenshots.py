#!/usr/bin/env python3
"""Boot iOS Simulator, capture real PureScan native UI screenshots (CN + EN),
and frame them into App Store 6.5" iPhone (1284x2778) and 13" iPad (2064x2752) showcases."""
from __future__ import annotations

import shutil
import subprocess
import sys
import time
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DERIVED = ROOT / "build" / "SimDerived"
RAW_DIR = ROOT / "build" / "raw_screens"
OUT_ROOT = Path("/Users/wang/OPC/media/20261120-purescan/appstore")

IPHONE_UDID = "763788AE-549A-4E0A-8D30-128A44F000E9"  # iPhone 18 Pro Max
IPAD_UDID = "578123F2-ECF5-49A3-AF3B-08157D9471AD"    # iPad Pro 13-inch (M5)
BUNDLE_ID = "com.yanghe.purescan"

FONT_CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_CN_FALLBACK = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_EN = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


def load_font(size: int, bold: bool = True, cn: bool = True) -> ImageFont.FreeTypeFont:
    if cn:
        if Path(FONT_CN).exists():
            try:
                return ImageFont.truetype(FONT_CN, size=size, index=2 if bold else 0)
            except Exception:
                return ImageFont.truetype(FONT_CN, size=size, index=0)
        return ImageFont.truetype(FONT_CN_FALLBACK, size=size, index=0)
    if Path(FONT_EN).exists():
        return ImageFont.truetype(FONT_EN, size=size)
    return ImageFont.truetype(FONT_CN, size=size, index=2 if bold else 0)


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=check, capture_output=True, text=True)


def build_sim_app() -> Path:
    print("[1/4] Building PureScan for iOS Simulator...")
    subprocess.run([
        "xcodebuild",
        "-project", str(ROOT / "PureScan.xcodeproj"),
        "-scheme", "PureScan",
        "-configuration", "Debug",
        "-destination", f"platform=iOS Simulator,id={IPHONE_UDID}",
        "-derivedDataPath", str(DERIVED),
        "CODE_SIGNING_ALLOWED=NO",
        "build",
    ], check=True)
    app_path = DERIVED / "Build" / "Products" / "Debug-iphonesimulator" / "PureScan.app"
    if not app_path.exists():
        raise RuntimeError(f"Built app not found at {app_path}")
    return app_path


def capture_device_screens(udid: str, app_path: Path, device_tag: str, screens: list[str], langs: list[str]) -> dict[tuple[str, str], Path]:
    print(f"[2/4] Booting simulator {device_tag} ({udid})...")
    run(["xcrun", "simctl", "boot", udid], check=False)
    run(["xcrun", "simctl", "bootstatus", udid, "-b"])
    run(["xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100", "--wifiBars", "3", "--cellularBars", "4"], check=False)
    run(["xcrun", "simctl", "install", udid, str(app_path)])

    captured: dict[tuple[str, str], Path] = {}
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    # Warm up simulator app process once
    run(["xcrun", "simctl", "launch", udid, BUNDLE_ID], check=False)
    time.sleep(3.0)
    run(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)
    time.sleep(0.5)

    for lang in langs:
        for screen in screens:
            run(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)
            time.sleep(0.5)
            run(["xcrun", "simctl", "launch", udid, BUNDLE_ID, "-ui_lang", lang, "-ui_demo_screen", screen])
            out_png = RAW_DIR / f"{device_tag}_{lang}_{screen}.png"
            # Wait until non-blank content renders (avoid capturing splash screen)
            for attempt in range(4):
                time.sleep(2.4 if attempt == 0 else 1.5)
                run(["xcrun", "simctl", "io", udid, "screenshot", str(out_png)])
                if out_png.stat().st_size > 45_000:
                    break
            captured[(lang, screen)] = out_png
            print(f"  ✓ Captured {out_png.name} ({out_png.stat().st_size // 1024} KB)")

    run(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)
    run(["xcrun", "simctl", "shutdown", udid], check=False)
    return captured


def draw_rounded_paste(canvas: Image.Image, shot: Image.Image, box: tuple[int, int, int, int], radius: int, bezel_color=(20, 21, 20)) -> None:
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    resized = shot.convert("RGBA").resize((w, h), Image.Resampling.LANCZOS)

    # Bezel shadow & frame
    draw = ImageDraw.Draw(canvas)
    pad = int(w * 0.022)
    draw.rounded_rectangle([x0 - pad, y0 - pad, x1 + pad, y1 + pad], radius=radius + pad, fill=bezel_color)

    mask = Image.new("L", (w, h), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle([0, 0, w, h], radius=radius, fill=255)
    canvas.paste(resized, (x0, y0), mask)


def compose_store_slide(
    raw_png: Path,
    out_png: Path,
    target_size: tuple[int, int],
    badge: str,
    title: str,
    subtitle: str,
    dark_bg: bool,
    is_cn: bool,
) -> None:
    W, H = target_size
    bg = (21, 22, 21) if dark_bg else (247, 245, 239)
    ink = (255, 255, 255) if dark_bg else (21, 21, 20)
    sub_ink = (205, 202, 194) if dark_bg else (96, 93, 86)
    accent = (220, 38, 38)

    canvas = Image.new("RGB", (W, H), bg)
    draw = ImageDraw.Draw(canvas)

    # Top accent pill
    f_badge = load_font(int(W * 0.032), bold=True, cn=is_cn)
    f_title = load_font(int(W * 0.066), bold=True, cn=is_cn)
    f_sub = load_font(int(W * 0.036), bold=False, cn=is_cn)

    tb = draw.textbbox((0, 0), badge, font=f_badge)
    bw, bh = tb[2] - tb[0], tb[3] - tb[1]
    px, py = int(W * 0.045), int(H * 0.013)
    pill_h = bh + py * 2
    pill_x0 = (W - bw - px * 2) // 2
    pill_y0 = int(H * 0.042)
    draw.rounded_rectangle([pill_x0, pill_y0, pill_x0 + bw + px * 2, pill_y0 + pill_h], radius=pill_h // 2, fill=accent)
    draw.text((pill_x0 + px - tb[0], pill_y0 + py - tb[1]), badge, font=f_badge, fill=(255, 255, 255))

    # Title (centered, supports \n)
    ty = pill_y0 + pill_h + int(H * 0.024)
    for line in title.split("\n"):
        lb = draw.textbbox((0, 0), line, font=f_title)
        lw = lb[2] - lb[0]
        draw.text(((W - lw) // 2 - lb[0], ty - lb[1]), line, font=f_title, fill=ink)
        ty += (lb[3] - lb[1]) + int(H * 0.014)

    # Subtitle
    sy = ty + int(H * 0.008)
    sb = draw.textbbox((0, 0), subtitle, font=f_sub)
    sw = sb[2] - sb[0]
    draw.text(((W - sw) // 2 - sb[0], sy - sb[1]), subtitle, font=f_sub, fill=sub_ink)

    # Framed live screenshot
    shot = Image.open(raw_png)
    shot_aspect = shot.width / shot.height
    frame_top = sy + (sb[3] - sb[1]) + int(H * 0.036)
    avail_h = H - frame_top - int(H * 0.035)
    avail_w = int(W * 0.80)
    if avail_w / avail_h > shot_aspect:
        fh = avail_h
        fw = int(fh * shot_aspect)
    else:
        fw = avail_w
        fh = int(fw / shot_aspect)
    fx0 = (W - fw) // 2
    fy0 = frame_top
    draw_rounded_paste(canvas, shot, (fx0, fy0, fx0 + fw, fy0 + fh), radius=int(fw * 0.085))

    out_png.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_png, "PNG")


def main() -> None:
    app_path = build_sim_app()
    screens = ["home", "result", "pk", "cabinet", "radar"]
    langs = ["zh", "en"]

    iphone_raw = capture_device_screens(IPHONE_UDID, app_path, "iphone65", screens, langs)
    ipad_raw = capture_device_screens(IPAD_UDID, app_path, "ipad13", screens, langs)

    copy_zh = {
        "home": ("0广告 · 离线秒扫", "不用条形码\n0.3 秒照穿配料表", "地下超市无网照扫 · 永不跳摇一摇广告", True),
        "result": ("GB 2760 + 6大雷达", "红黄绿荧光标雷\n一键盖章能不能买", "脱氢乙酸钠、反式脂肪、隐形糖瞬间现形", False),
        "pk": ("超市纠结终结者", "两包商品同屏 PK\n1 秒比出谁更干净", "左扫一包右扫一包 · 一键导出避雷对比图", True),
        "radar": ("6 大个人忌口雷达", "控糖 · 痛风 · 宝妈\n护肤与猫狗粮全覆盖", "揪出痛风酵母抽提物 & 猫粮谷物分割法", False),
        "cabinet": ("我的红黑囤货柜", "安心回购 vs 永久拉黑\n逛超市不再踩同一坑", "免登录本地保存 · 每天免费扫 10 次", False),
    }
    copy_en = {
        "home": ("ZERO ADS · 100% OFFLINE", "Skip Broken Barcodes.\nScan Any Label in 0.3s", "On-device Apple Vision OCR — no signal needed", True),
        "result": ("PERSONALIZED RADARS", "Instant Red-Flag\nHighlights & Score", "Spot additives, trans fats & hidden sugars fast", False),
        "pk": ("SUPERMARKET SHOWDOWN", "Compare Two Labels\nSide-by-Side in 1s", "Pick the cleaner yogurt, bread, or pet food", True),
        "radar": ("6 CUSTOM HEALTH RADARS", "Low Sugar · Gout\nSkincare & Pet Food", "Catches purines, comedogenic esters & grain splitting", False),
        "cabinet": ("RED & GREEN CABINET", "Save Buy-Again Picks\nBlacklist Junk Forever", "No forced login · 10 free offline scans daily", False),
    }

    print("[3/4] Compositing CN & EN App Store screenshots (6.5\" iPhone + 13\" iPad)...")
    for idx, sc in enumerate(screens, start=1):
        for lang, locale_dir, copy_map, is_cn in [
            ("zh", "zh-Hans", copy_zh, True),
            ("en", "en-US", copy_en, False),
        ]:
            badge, title, sub, dark = copy_map[sc]
            compose_store_slide(
                iphone_raw[(lang, sc)],
                OUT_ROOT / locale_dir / "iphone65" / f"{idx:02d}_{sc}.png",
                (1284, 2778),
                badge, title, sub, dark, is_cn,
            )
            compose_store_slide(
                ipad_raw[(lang, sc)],
                OUT_ROOT / locale_dir / "ipad13" / f"{idx:02d}_{sc}.png",
                (2064, 2752),
                badge, title, sub, dark, is_cn,
            )

    print(f"[4/4] Done! Framed App Store screenshots saved in {OUT_ROOT}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate ready-to-post Xiaohongshu 3:4 viral covers AND a crisp 15-second 9:16 vertical demo video
using real iOS Simulator captures from build/raw_screens/."""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "build" / "raw_screens"
MEDIA_OUT = ROOT / "release" / "media"
TMP_VID = ROOT / "build" / "video_frames"

FONT_CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_CN_FALLBACK = "/System/Library/Fonts/STHeiti Medium.ttc"


def font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    if Path(FONT_CN).exists():
        try:
            return ImageFont.truetype(FONT_CN, size=size, index=2 if bold else 0)
        except Exception:
            return ImageFont.truetype(FONT_CN, size=size, index=0)
    return ImageFont.truetype(FONT_CN_FALLBACK, size=size, index=0)


def paste_phone(canvas: Image.Image, shot_path: Path, box: tuple[int, int, int, int], radius: int = 44) -> None:
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    shot = Image.open(shot_path).convert("RGBA").resize((w, h), Image.Resampling.LANCZOS)
    draw = ImageDraw.Draw(canvas)
    pad = 14
    draw.rounded_rectangle([x0 - pad, y0 - pad, x1 + pad, y1 + pad], radius=radius + pad, fill=(20, 21, 20))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w, h], radius=radius, fill=255)
    canvas.paste(shot, (x0, y0), mask)


def make_xhs_card(
    out_path: Path,
    tag: str,
    headline: str,
    sub: str,
    shot_left: Path,
    shot_right: Path | None = None,
    dark: bool = False,
) -> None:
    W, H = 1242, 1656  # Classic 3:4 Xiaohongshu crisp ratio
    bg = (21, 22, 21) if dark else (247, 245, 239)
    ink = (255, 255, 255) if dark else (21, 21, 20)
    sub_ink = (205, 202, 195) if dark else (95, 92, 86)
    red = (220, 38, 38)

    img = Image.new("RGB", (W, H), bg)
    draw = ImageDraw.Draw(img)

    # Top red punch tag
    f_tag = font(34, True)
    tb = draw.textbbox((0, 0), tag, font=f_tag)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    pill_h = th + 32
    draw.rounded_rectangle([72, 58, 72 + tw + 56, 58 + pill_h], radius=pill_h // 2, fill=red)
    draw.text((100 - tb[0], 74 - tb[1]), tag, font=f_tag, fill=(255, 255, 255))

    # Big viral hook headline (3-second stop-scroll)
    f_head = font(68, True)
    hy = 156
    for line in headline.split("\n"):
        lb = draw.textbbox((0, 0), line, font=f_head)
        draw.text((72 - lb[0], hy - lb[1]), line, font=f_head, fill=ink)
        hy += (lb[3] - lb[1]) + 22

    f_sub = font(34, False)
    sb = draw.textbbox((0, 0), sub, font=f_sub)
    draw.text((72 - sb[0], hy + 10 - sb[1]), sub, font=f_sub, fill=sub_ink)

    top_y = hy + (sb[3] - sb[1]) + 54
    if shot_right is None:
        s = Image.open(shot_left)
        aspect = s.width / s.height
        fh = H - top_y - 62
        fw = int(fh * aspect)
        fx0 = (W - fw) // 2
        paste_phone(img, shot_left, (fx0, top_y, fx0 + fw, top_y + fh), radius=46)
    else:
        # Side-by-side dual phone showcase
        s = Image.open(shot_left)
        aspect = s.width / s.height
        fw = 490
        fh = min(H - top_y - 60, int(fw / aspect))
        fw = int(fh * aspect)
        gap = 56
        start_x = (W - (fw * 2 + gap)) // 2
        paste_phone(img, shot_left, (start_x, top_y + 18, start_x + fw, top_y + 18 + fh), radius=38)
        paste_phone(img, shot_right, (start_x + fw + gap, top_y, start_x + fw * 2 + gap, top_y + fh), radius=38)

    img.save(out_path, "PNG")
    print(f"  ✓ Saved XHS poster {out_path.name} ({out_path.stat().st_size // 1024} KB)")


def make_video_scene(
    out_png: Path,
    kicker: str,
    big_text: str,
    shot_path: Path,
    footer: str,
    bg_color: tuple[int, int, int],
    accent: tuple[int, int, int],
) -> None:
    W, H = 1080, 1920
    img = Image.new("RGB", (W, H), bg_color)
    draw = ImageDraw.Draw(img)
    dark = sum(bg_color) < 300
    ink = (255, 255, 255) if dark else (21, 21, 20)

    f_k = font(36, True)
    kb = draw.textbbox((0, 0), kicker, font=f_k)
    kw, kh = kb[2] - kb[0], kb[3] - kb[1]
    pill_h = kh + 34
    kx0 = (W - kw - 64) // 2
    draw.rounded_rectangle([kx0, 108, kx0 + kw + 64, 108 + pill_h], radius=pill_h // 2, fill=accent)
    draw.text((kx0 + 32 - kb[0], 125 - kb[1]), kicker, font=f_k, fill=(255, 255, 255))

    f_b = font(64, True)
    by = 225
    for line in big_text.split("\n"):
        lb = draw.textbbox((0, 0), line, font=f_b)
        draw.text(((W - (lb[2] - lb[0])) // 2 - lb[0], by - lb[1]), line, font=f_b, fill=ink)
        by += (lb[3] - lb[1]) + 20

    s = Image.open(shot_path)
    aspect = s.width / s.height
    top_y = by + 36
    fh = 1220
    fw = int(fh * aspect)
    fx0 = (W - fw) // 2
    paste_phone(img, shot_path, (fx0, top_y, fx0 + fw, top_y + fh), radius=46)

    f_f = font(36, True)
    fb = draw.textbbox((0, 0), footer, font=f_f)
    draw.text(((W - (fb[2] - fb[0])) // 2, H - 120), footer, font=f_f, fill=accent if not dark else (255, 210, 80))

    img.save(out_png, "PNG")


def build_15s_video() -> Path:
    TMP_VID.mkdir(parents=True, exist_ok=True)
    scenes = [
        (
            "s1.png", 3.2,
            "受够扫配料跳 10 次广告？",
            "自己写了个 0 广告\n离线「配料照妖镜」",
            RAW_DIR / "iphone65_zh_home.png",
            "地下超市没网照样 0.3 秒直出",
            (21, 22, 21), (220, 38, 38),
        ),
        (
            "s2.png", 3.8,
            "实测网红手撕吐司",
            "一扫揪出脱氢乙酸钠\n氢化植物油 + 柠檬黄！",
            RAW_DIR / "iphone65_zh_result.png",
            "红黄绿荧光标雷 · 18分红章劝退",
            (247, 245, 239), (220, 38, 38),
        ),
        (
            "s3.png", 4.0,
            "超市纠结买哪包？",
            "左扫右扫同屏 PK\n1 秒盖章谁更干净",
            RAW_DIR / "iphone65_zh_pk.png",
            "吐司 18分 VS 极简酸奶 100分",
            (21, 22, 21), (17, 138, 84),
        ),
        (
            "s4.png", 4.0,
            "6 大专属忌口雷达",
            "控糖·痛风·宝妈\n护肤与猫狗粮全覆盖",
            RAW_DIR / "iphone65_zh_radar.png",
            "App Store 搜「配料照妖镜」免费日扫10次",
            (247, 245, 239), (220, 38, 38),
        ),
    ]

    concat_lines = []
    for fname, dur, kicker, big, shot, footer, bg, accent in scenes:
        p = TMP_VID / fname
        make_video_scene(p, kicker, big, shot, footer, bg, accent)
        concat_lines.append(f"file '{p.as_posix()}'")
        concat_lines.append(f"duration {dur}")
    concat_lines.append(f"file '{(TMP_VID / scenes[-1][0]).as_posix()}'")

    list_file = TMP_VID / "concat.txt"
    list_file.write_text("\n".join(concat_lines) + "\n", encoding="utf-8")

    # Generate crisp subtle UI chime audio via Python wave (zero lavfi parser quirks)
    import math, struct, wave
    audio_wav = TMP_VID / "chime.wav"
    sr = 44100
    dur_s = 15.0
    n_samples = int(sr * dur_s)
    chime_marks = [(0.1, 523.25), (3.2, 659.25), (7.0, 783.99), (11.0, 1046.50)]
    with wave.open(str(audio_wav), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        buf = bytearray()
        for i in range(n_samples):
            t = i / sr
            val = 0.0
            for start, freq in chime_marks:
                dt = t - start
                if 0.0 <= dt < 1.2:
                    env = math.exp(-4.5 * dt)
                    val += 0.22 * env * math.sin(2.0 * math.pi * freq * dt)
                    val += 0.08 * env * math.sin(2.0 * math.pi * (freq * 1.5) * dt)
            sample = max(-32767, min(32767, int(val * 32767)))
            buf.extend(struct.pack("<h", sample))
        wf.writeframes(bytes(buf))

    out_mp4 = MEDIA_OUT / "purescan_hook_15s_9x16.mp4"
    subprocess.run([
        "/Users/wang/.local/bin/ffmpeg", "-y",
        "-f", "concat", "-safe", "0", "-i", str(list_file),
        "-i", str(audio_wav),
        "-vf", "fps=30,format=yuv420p",
        "-c:v", "libx264", "-preset", "medium", "-crf", "23",
        "-c:a", "aac", "-b:a", "128k",
        "-shortest", "-movflags", "+faststart",
        str(out_mp4),
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    size_mb = out_mp4.stat().st_size / (1024 * 1024)
    print(f"  ✓ Built 15s 9:16 viral demo video: {out_mp4} ({size_mb:.2f} MB)")
    shutil.rmtree(TMP_VID, ignore_errors=True)
    return out_mp4


def main() -> None:
    MEDIA_OUT.mkdir(parents=True, exist_ok=True)
    print("Generating Xiaohongshu 3:4 viral launch posters...")
    make_xhs_card(
        MEDIA_OUT / "xhs_01_cover_story.png",
        "独立开发 · 0广告离线工具",
        "受够扫配料跳 10 次广告\n我自己搓了个配料照妖镜",
        "不用条形码 · 地下超市 0.3 秒离线照穿狠活",
        RAW_DIR / "iphone65_zh_home.png",
        RAW_DIR / "iphone65_zh_result.png",
        dark=True,
    )
    make_xhs_card(
        MEDIA_OUT / "xhs_02_toast_vs_yogurt.png",
        "超市货架红黑实测",
        "一扫吓一跳！网红吐司\nvs 极简酸奶配料大决战",
        "脱氢乙酸钠 · 氢化植物油 · 柠檬黄瞬间标红",
        RAW_DIR / "iphone65_zh_result.png",
        RAW_DIR / "iphone65_zh_pk.png",
        dark=False,
    )
    make_xhs_card(
        MEDIA_OUT / "xhs_03_6_radars.png",
        "全家人定制避雷",
        "6 大专属忌口雷达\n按你的身体精准亮红灯",
        "控糖减脂 · 痛风高尿酸 · 宝妈 · 敏肌 · 猫狗粮",
        RAW_DIR / "iphone65_zh_radar.png",
        dark=False,
    )
    make_xhs_card(
        MEDIA_OUT / "xhs_04_gout_pet_trap.png",
        "痛风党 & 养猫人必看",
        "抓出零添加里的嘌呤炸弹\n识破猫粮「谷物分割法」",
        "囤货柜一键收藏安心回购 · 踩雷货永久拉黑",
        RAW_DIR / "iphone65_zh_cabinet.png",
        dark=True,
    )
    print("Building 15s 9:16 Xiaohongshu / Douyin hook demo video...")
    build_15s_video()


if __name__ == "__main__":
    main()

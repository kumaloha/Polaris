#!/usr/bin/env python3
"""Utilities for cleaning dragon video frames and aligning dragons by foot baseline.

The youth/big-dragon source frames are 1440x1440 green-screen PNGs with a
bottom-right Vidu watermark.  They must be cleaned before game/preview use, and
both baby/youth dragons must be positioned by the visible foot baseline rather
than by the texture center.
"""

from __future__ import annotations

import argparse
import shutil
import struct
import subprocess
import tempfile
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BABY_SRC = ROOT / "resources/dragon_baby/dragon_frames"
DEFAULT_BABY_DST = ROOT / "godot/assets/pets/dragon_baby/frames"
DEFAULT_BABY_FRAME = DEFAULT_BABY_DST / "dragon_00.png"
DEFAULT_YOUTH_SRC = ROOT / "resources/dragon_youth"
DEFAULT_YOUTH_DST = ROOT / "godot/assets/pets/dragon_youth/frames"
DEFAULT_YOUTH_FRAME = DEFAULT_YOUTH_DST / "frame_001.png"
DEFAULT_PREVIEW_OUT = ROOT / "resources/dragon_youth/preview_aligned.png"


@dataclass(frozen=True)
class Rect:
    left: int
    top: int
    right: int
    bottom: int

    @property
    def width(self) -> int:
        return self.right - self.left

    @property
    def height(self) -> int:
        return self.bottom - self.top


@dataclass(frozen=True)
class Placement:
    x: float
    y: float
    scale: float


def place_bbox_on_baseline(bbox: Rect, visible_width: float, x: float, baseline_y: float) -> Placement:
    """Return full-texture top-left placement so bbox bottom lands on baseline.

    `x` is the desired visible bbox left edge, not the texture's left edge.
    This keeps the dragon's foot/contact point stable even when source images
    have different transparent margins or canvas sizes.
    """
    if bbox.width <= 0:
        raise ValueError(f"invalid bbox width: {bbox}")
    scale = visible_width / float(bbox.width)
    return Placement(
        x=x - float(bbox.left) * scale,
        y=baseline_y - float(bbox.bottom) * scale,
        scale=scale,
    )


def youth_clean_filter() -> str:
    """FFmpeg filter chain for youth dragon source frames.

    The watermark is white/gray, so chromakey alone keeps it.  First paint the
    known watermark corner back to the same green-screen color, then key green
    to transparent RGBA.
    """
    return "drawbox=x=1190:y=1300:w=250:h=140:color=0x94cc99@1:t=fill,colorkey=0x94cc99:0.18:0.04,format=rgba"


def _run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def clean_youth_frame(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    _run([
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(src),
        "-vf", youth_clean_filter(),
        str(dst),
    ])


def clean_youth_frames(src_dir: Path = DEFAULT_YOUTH_SRC, dst_dir: Path = DEFAULT_YOUTH_DST) -> None:
    dst_dir.mkdir(parents=True, exist_ok=True)
    pattern = src_dir / "frame_%03d.png"
    out_pattern = dst_dir / "frame_%03d.png"
    _run([
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-start_number", "1",
        "-i", str(pattern),
        "-vf", youth_clean_filter(),
        str(out_pattern),
    ])


def install_baby_frames(src_dir: Path = DEFAULT_BABY_SRC, dst_dir: Path = DEFAULT_BABY_DST) -> None:
    """Install watermark-free baby PNG sequence into the Godot asset tree.

    Do not use dragon_final_v10.mp4 for game/preview rendering: that video has
    a Vidu watermark.  The transparent PNG sequence is the canonical baby
    dragon source.
    """
    dst_dir.mkdir(parents=True, exist_ok=True)
    for src in sorted(src_dir.glob("dragon_*.png")):
        if not has_no_bottom_right_watermark(src):
            raise ValueError(f"baby frame still has a bottom-right watermark: {src}")
        shutil.copy2(src, dst_dir / src.name)


def _read_png_rgba(path: Path) -> tuple[int, int, int, list[list[int]]]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not a PNG: {path}")
    pos = 8
    width = height = bit_depth = color_type = None
    idat = b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        pos += 4
        chunk_type = data[pos:pos + 4]
        pos += 4
        chunk = data[pos:pos + length]
        pos += length + 4  # skip crc too
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _comp, _flt, interlace = struct.unpack(">IIBBBBB", chunk)
            if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
                raise ValueError(f"unsupported PNG format for {path}: {(width, height, bit_depth, color_type, interlace)}")
        elif chunk_type == b"IDAT":
            idat += chunk
        elif chunk_type == b"IEND":
            break
    if width is None or height is None or color_type is None:
        raise ValueError(f"missing PNG header: {path}")
    bpp = 4 if color_type == 6 else 3
    stride = width * bpp
    raw = zlib.decompress(idat)
    rows: list[list[int]] = []
    i = 0
    previous = [0] * stride
    for _y in range(height):
        filter_type = raw[i]
        i += 1
        scan = list(raw[i:i + stride])
        i += stride
        row = [0] * stride
        for x in range(stride):
            left = row[x - bpp] if x >= bpp else 0
            up = previous[x]
            up_left = previous[x - bpp] if x >= bpp else 0
            value = scan[x]
            if filter_type == 0:
                pass
            elif filter_type == 1:
                value = (value + left) & 255
            elif filter_type == 2:
                value = (value + up) & 255
            elif filter_type == 3:
                value = (value + ((left + up) // 2)) & 255
            elif filter_type == 4:
                p = left + up - up_left
                pa = abs(p - left)
                pb = abs(p - up)
                pc = abs(p - up_left)
                predictor = left if pa <= pb and pa <= pc else (up if pb <= pc else up_left)
                value = (value + predictor) & 255
            else:
                raise ValueError(f"unsupported PNG filter {filter_type} in {path}")
            row[x] = value
        rows.append(row)
        previous = row
    return width, height, bpp, rows


def alpha_bbox(path: Path, min_alpha: int = 8) -> Rect:
    width, height, bpp, rows = _read_png_rgba(path)
    min_x = width
    min_y = height
    max_x = -1
    max_y = -1
    for y, row in enumerate(rows):
        for x in range(width):
            alpha = row[x * bpp + 3] if bpp == 4 else 255
            if alpha >= min_alpha:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    if max_x < min_x or max_y < min_y:
        raise ValueError(f"no visible pixels in {path}")
    return Rect(min_x, min_y, max_x + 1, max_y + 1)


def has_no_bottom_right_watermark(path: Path, min_alpha: int = 8) -> bool:
    """Return true when the usual video watermark corner is fully transparent."""
    width, height, bpp, rows = _read_png_rgba(path)
    x0 = int(float(width) * 0.86)
    y0 = int(float(height) * 0.90)
    for y in range(y0, height):
        row = rows[y]
        for x in range(x0, width):
            alpha = row[x * bpp + 3] if bpp == 4 else 255
            if alpha >= min_alpha:
                return False
    return True


def _scaled_size(path: Path, scale: float) -> tuple[int, int]:
    width, height, _bpp, _rows = _read_png_rgba(path)
    return max(1, round(width * scale)), max(1, round(height * scale))


def render_aligned_preview(
    baby_frame: Path = DEFAULT_BABY_FRAME,
    youth_frame: Path = DEFAULT_YOUTH_FRAME,
    out: Path = DEFAULT_PREVIEW_OUT,
    canvas_size: tuple[int, int] = (888, 316),
    baseline_y: int = 284,
) -> None:
    """Render a side-by-side preview with baby and youth dragons sharing foot line."""
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="dragon-preview-") as tmp_raw:
        tmp = Path(tmp_raw)
        clean_youth = tmp / "youth_clean.png"
        clean_youth_frame(youth_frame, clean_youth)
        baby_bbox = alpha_bbox(baby_frame)
        youth_bbox = alpha_bbox(clean_youth)
        baby_place = place_bbox_on_baseline(baby_bbox, visible_width=190, x=62, baseline_y=baseline_y)
        youth_place = place_bbox_on_baseline(youth_bbox, visible_width=430, x=430, baseline_y=baseline_y)
        baby_w, baby_h = _scaled_size(baby_frame, baby_place.scale)
        youth_w, youth_h = _scaled_size(clean_youth, youth_place.scale)
        filter_complex = (
            f"color=c=0xc39a74:s={canvas_size[0]}x{canvas_size[1]}[bg];"
            f"[0:v]scale={baby_w}:{baby_h}:flags=lanczos[small];"
            f"[1:v]scale={youth_w}:{youth_h}:flags=lanczos[big];"
            f"[bg][small]overlay={round(baby_place.x)}:{round(baby_place.y)}[tmp];"
            f"[tmp][big]overlay={round(youth_place.x)}:{round(youth_place.y)}"
        )
        _run([
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-i", str(baby_frame),
            "-i", str(clean_youth),
            "-filter_complex", filter_complex,
            "-frames:v", "1",
            str(out),
        ])


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    clean = sub.add_parser("clean-youth", help="clean all youth dragon frames into Godot assets")
    clean.add_argument("--src", type=Path, default=DEFAULT_YOUTH_SRC)
    clean.add_argument("--dst", type=Path, default=DEFAULT_YOUTH_DST)

    baby = sub.add_parser("install-baby", help="install clean baby PNG frames into Godot assets")
    baby.add_argument("--src", type=Path, default=DEFAULT_BABY_SRC)
    baby.add_argument("--dst", type=Path, default=DEFAULT_BABY_DST)

    preview = sub.add_parser("preview", help="render baby/youth baseline-aligned preview")
    preview.add_argument("--baby", type=Path, default=DEFAULT_BABY_FRAME)
    preview.add_argument("--youth", type=Path, default=DEFAULT_YOUTH_FRAME)
    preview.add_argument("--out", type=Path, default=DEFAULT_PREVIEW_OUT)

    args = parser.parse_args(list(argv) if argv is not None else None)
    if not shutil.which("ffmpeg"):
        raise SystemExit("ffmpeg is required for dragon asset cleanup")
    if args.cmd == "clean-youth":
        clean_youth_frames(args.src, args.dst)
        return 0
    if args.cmd == "install-baby":
        install_baby_frames(args.src, args.dst)
        return 0
    if args.cmd == "preview":
        render_aligned_preview(args.baby, args.youth, args.out)
        return 0
    raise SystemExit(f"unknown command: {args.cmd}")


if __name__ == "__main__":
    raise SystemExit(main())

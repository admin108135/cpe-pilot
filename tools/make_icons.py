#!/usr/bin/env python3
"""把 1024x1024 的源图标切成 Android 各密度 mipmap 图标。"""
import os
import sys

from PIL import Image

SIZES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}


def main() -> int:
    if len(sys.argv) != 3:
        print('usage: make_icons.py <source.png> <res_dir>')
        return 2
    src, res_dir = sys.argv[1], sys.argv[2]
    img = Image.open(src).convert('RGBA')
    for folder, size in SIZES.items():
        out = os.path.join(res_dir, folder)
        os.makedirs(out, exist_ok=True)
        img.resize((size, size), Image.LANCZOS).save(
            os.path.join(out, 'ic_launcher.png'))
        print('wrote', os.path.join(out, 'ic_launcher.png'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

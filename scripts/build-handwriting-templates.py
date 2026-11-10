#!/usr/bin/env python3
"""Builds FlashcardApp/Resources/HandwritingTemplates.bin from a KanjiVG release (the "main" zip, unpacked).

Usage: scripts/build-handwriting-templates.py <path-to-kanjivg>/kanji FlashcardApp/Resources/HandwritingTemplates.bin

KanjiVG is (c) Ulrich Apel, CC BY-SA 3.0 (https://kanjivg.tagaini.net). The output keeps only each character's strokes,
resampled to POINTS points, so it is a derived work under the same licence.

File layout (little endian): "KVGH", u8 version = 1, u8 points per stroke, u32 character count, then per character:
u32 Unicode scalar, u8 stroke count, stroke count * POINTS * (u8 x, u8 y) in KanjiVG's 109 x 109 grid, stored * 2.
"""
import math
import re
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

POINTS = 12
VERSION = 1
SVG = "{http://www.w3.org/2000/svg}"
TOKEN = re.compile(r"[MmLlHhVvCcSsQqTtZz]|-?\d*\.?\d+(?:e-?\d+)?")


def cubic(p0, p1, p2, p3, steps=16):
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        yield (u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
               u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1])


def quadratic(p0, p1, p2, steps=12):
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        yield (u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0], u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1])


def flatten(d):
    tokens = TOKEN.findall(d)
    i, cmd, cur, start, last_c2, last_q = 0, None, (0.0, 0.0), (0.0, 0.0), None, None
    points = []

    def num():
        nonlocal i
        value = float(tokens[i])
        i += 1
        return value

    while i < len(tokens):
        if tokens[i].isalpha():
            cmd = tokens[i]
            i += 1
            if cmd in "Zz":
                cur = start
                continue
        rel = cmd.islower()
        c = cmd.upper()
        ox, oy = cur if rel else (0.0, 0.0)
        if c == "M":
            cur = (ox + num(), oy + num())
            start = cur
            points.append(cur)
            cmd = "l" if rel else "L"
            last_c2 = last_q = None
        elif c == "L":
            cur = (ox + num(), oy + num())
            points.append(cur)
            last_c2 = last_q = None
        elif c == "H":
            cur = ((cur[0] if rel else 0.0) + num(), cur[1])
            points.append(cur)
            last_c2 = last_q = None
        elif c == "V":
            cur = (cur[0], (cur[1] if rel else 0.0) + num())
            points.append(cur)
            last_c2 = last_q = None
        elif c == "C":
            p1 = (ox + num(), oy + num())
            p2 = (ox + num(), oy + num())
            p3 = (ox + num(), oy + num())
            points.extend(cubic(cur, p1, p2, p3))
            cur, last_c2, last_q = p3, p2, None
        elif c == "S":
            p1 = (2 * cur[0] - last_c2[0], 2 * cur[1] - last_c2[1]) if last_c2 else cur
            p2 = (ox + num(), oy + num())
            p3 = (ox + num(), oy + num())
            points.extend(cubic(cur, p1, p2, p3))
            cur, last_c2, last_q = p3, p2, None
        elif c == "Q":
            p1 = (ox + num(), oy + num())
            p2 = (ox + num(), oy + num())
            points.extend(quadratic(cur, p1, p2))
            cur, last_q, last_c2 = p2, p1, None
        elif c == "T":
            p1 = (2 * cur[0] - last_q[0], 2 * cur[1] - last_q[1]) if last_q else cur
            p2 = (ox + num(), oy + num())
            points.extend(quadratic(cur, p1, p2))
            cur, last_q, last_c2 = p2, p1, None
        else:
            raise ValueError(f"unsupported path command {cmd}")
    return points


def resample(points, count):
    lengths = [0.0]
    for a, b in zip(points, points[1:]):
        lengths.append(lengths[-1] + math.dist(a, b))
    total = lengths[-1]
    if total == 0:
        return [points[0]] * count
    out, j = [], 0
    for k in range(count):
        target = total * k / (count - 1)
        while j < len(lengths) - 2 and lengths[j + 1] < target:
            j += 1
        span = lengths[j + 1] - lengths[j]
        t = 0 if span == 0 else (target - lengths[j]) / span
        a, b = points[j], points[j + 1]
        out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def wanted(code):
    return 0x3041 <= code <= 0x3096 or 0x30A1 <= code <= 0x30FA or 0x4E00 <= code <= 0x9FFF


def main(source, target):
    entries = []
    for path in sorted(Path(source).glob("*.svg")):
        if "-" in path.stem:
            continue  # variants such as 0f9a8-Kaisho
        code = int(path.stem, 16)
        if not wanted(code):
            continue
        root = ET.parse(path).getroot()
        strokes = [resample(flatten(p.get("d")), POINTS) for p in root.iter(SVG + "path") if p.get("d")]
        if not strokes or len(strokes) > 40:
            continue
        entries.append((code, strokes))
    with open(target, "wb") as out:
        out.write(b"KVGH" + struct.pack("<BBI", VERSION, POINTS, len(entries)))
        for code, strokes in entries:
            out.write(struct.pack("<IB", code, len(strokes)))
            for stroke in strokes:
                for x, y in stroke:
                    out.write(struct.pack("<BB", min(255, round(x * 2)), min(255, round(y * 2))))
    print(f"{len(entries)} characters")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])

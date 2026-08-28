#!/usr/bin/env python3
"""Order an ImageMagick histogram into a perceptually diverse palette.

Input is `histogram:info:-` output on stdin. The implementation intentionally
uses only Python's standard library so the Quickshell theme has no Pillow
runtime dependency.
"""

from __future__ import annotations

import colorsys
import math
import re
import sys


def srgb_linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def oklab(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    red, green, blue = (srgb_linear(value / 255.0) for value in rgb)
    l_value = 0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue
    m_value = 0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue
    s_value = 0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue
    l_root, m_root, s_root = (value ** (1.0 / 3.0) for value in (l_value, m_value, s_value))
    return (
        0.2104542553 * l_root + 0.7936177850 * m_root - 0.0040720468 * s_root,
        1.9779984951 * l_root - 2.4285922050 * m_root + 0.4505937099 * s_root,
        0.0259040371 * l_root + 0.7827717662 * m_root - 0.8086757660 * s_root,
    )


def distance(first: tuple[float, ...], second: tuple[float, ...]) -> float:
    return math.sqrt(sum((left - right) ** 2 for left, right in zip(first, second)))


entries: list[dict[str, object]] = []
for line in sys.stdin:
    match = re.search(r"([0-9]+):.*#([0-9A-Fa-f]{6})", line)
    if not match:
        continue
    population = int(match.group(1))
    hex_value = match.group(2).upper()
    rgb = tuple(int(hex_value[index : index + 2], 16) for index in (0, 2, 4))
    saturation = colorsys.rgb_to_hsv(*(value / 255.0 for value in rgb))[1]
    entries.append(
        {
            "population": population,
            "hex": f"#{hex_value}",
            "saturation": saturation,
            "oklab": oklab(rgb),
        }
    )

if entries:
    max_population = max(int(entry["population"]) for entry in entries)
    selected: list[dict[str, object]] = []

    while entries and len(selected) < 12:
        def score(entry: dict[str, object]) -> float:
            popularity = int(entry["population"]) / max_population
            saturation = float(entry["saturation"])
            if not selected:
                return 0.70 * popularity + 0.30 * saturation
            separation = min(
                distance(entry["oklab"], chosen["oklab"])  # type: ignore[arg-type]
                for chosen in selected
            )
            return 1.80 * separation + 0.30 * saturation + 0.12 * popularity

        chosen = max(entries, key=score)
        selected.append(chosen)
        entries.remove(chosen)

    sys.stdout.write("\n".join(str(entry["hex"]) for entry in selected))
    sys.stdout.write("\n")

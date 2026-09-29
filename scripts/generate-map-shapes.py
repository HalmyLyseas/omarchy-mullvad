#!/usr/bin/env python3
"""Regenerate NaturalEarthMap.qml from Natural Earth's 1:50m GeoJSON."""

import json
from pathlib import Path
from urllib.request import urlopen

BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/ca96624a56bd078437bca8184e78163e5039ad19/geojson/"
ROOT = Path(__file__).resolve().parent.parent
TOLERANCE = 0.3


def distance_squared(point, start, end):
    dx, dy = end[0] - start[0], end[1] - start[1]
    length_squared = dx * dx + dy * dy
    if not length_squared:
        return (point[0] - start[0]) ** 2 + (point[1] - start[1]) ** 2
    fraction = max(0, min(1, ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / length_squared))
    x, y = start[0] + fraction * dx, start[1] + fraction * dy
    return (point[0] - x) ** 2 + (point[1] - y) ** 2


def simplify(points):
    if len(points) < 4:
        return points
    index = max(range(1, len(points) - 1), key=lambda i: distance_squared(points[i], points[0], points[-1]))
    if distance_squared(points[index], points[0], points[-1]) <= TOLERANCE ** 2:
        return [points[0], points[-1]]
    return simplify(points[:index + 1])[:-1] + simplify(points[index:])


def projected_path(coordinates, closed):
    points = [((lon + 180) * 1000 / 360, (90 - lat) * 500 / 180) for lon, lat in coordinates]
    reduced = simplify(points)
    if closed and len(reduced) < 4:
        reduced = points
    return "M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in reduced) + ("Z" if closed else "")


def paths(filename, polygon):
    with urlopen(BASE + filename, timeout=30) as response:
        features = json.load(response)["features"]
    output = []
    for feature in features:
        geometry = feature["geometry"]
        kind, coordinates = geometry["type"], geometry["coordinates"]
        shapes = coordinates if kind.startswith("Multi") else [coordinates]
        for shape in shapes:
            lines = shape if polygon else [shape]
            for line in lines:
                output.append(projected_path(line, polygon))
    return "".join(output)


land = paths("ne_50m_land.geojson", True)
borders = paths("ne_50m_admin_0_boundary_lines_land.geojson", False)
source = f'''import QtQuick
import QtQuick.Shapes
import qs.Commons

// Natural Earth 1:50m land and international boundaries, simplified to 0.3 map units.
Shape {{
  id: root
  property color foreground: Color.foreground
  property real zoomLevel: 1
  antialiasing: true

  ShapePath {{
    fillColor: Util.alpha(root.foreground, 0.13)
    strokeColor: Util.alpha(root.foreground, 0.48)
    strokeWidth: 1.6 / root.zoomLevel
    fillRule: ShapePath.OddEvenFill
    PathSvg {{ path: {json.dumps(land)} }}
  }}

  ShapePath {{
    fillColor: "transparent"
    strokeColor: Util.alpha(root.foreground, 0.29)
    strokeWidth: 1 / root.zoomLevel
    PathSvg {{ path: {json.dumps(borders)} }}
  }}
}}
'''
(ROOT / "NaturalEarthMap.qml").write_text(source)
print(f"Wrote NaturalEarthMap.qml ({len(source):,} bytes)")

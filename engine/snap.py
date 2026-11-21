"""Display-only snapping of synthetic positions into real BMC ward polygons (engine/geo/wards_real.geojson).
Standard library only. Nothing here feeds scoring or grouping: those use the dataset's original coordinates."""
import json, math
from pathlib import Path

KX, KY = 111320 * math.cos(math.radians(19.07)), 110540  # metres per degree of lon / lat around Mumbai
NUDGE_M, STEP_M = 40, 20
BBOX = (18.85, 19.35, 72.75, 73.05)  # lat min/max, lon min/max: Greater Mumbai with margin


def in_ring(x, y, ring):
    inside = False
    for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1]):
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1): inside = not inside
    return inside

def area(ring): return sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1])) / 2


class Wards:
    def __init__(self, path):
        g = json.loads(Path(path).read_text(encoding="utf-8"))
        self.polys = {}  # ward_code -> [polygon]; polygon = [outer ring, *holes]; ring = [(x, y) metres]
        for f in g["features"]:
            geo = f["geometry"]
            ps = geo["coordinates"] if geo["type"] == "MultiPolygon" else [geo["coordinates"]]
            self.polys[f["properties"]["ward_code"]] = [[[(p[0] * KX, p[1] * KY) for p in ring] for ring in poly] for poly in ps]
        self.rep = {code: self._rep(ps) for code, ps in self.polys.items()}

    def _in(self, code, x, y):
        return any(in_ring(x, y, p[0]) and not any(in_ring(x, y, h) for h in p[1:]) for p in self.polys[code])

    def _rep(self, ps):
        """An interior point of the largest polygon: its area centroid if inside, else the middle of the widest
        interior stretch of a horizontal scan line."""
        p = max(ps, key=lambda p: abs(area(p[0])))
        o, a = p[0], area(p[0])
        cx = sum((x1 + x2) * (x1 * y2 - x2 * y1) for (x1, y1), (x2, y2) in zip(o, o[1:] + o[:1])) / (6 * a)
        cy = sum((y1 + y2) * (x1 * y2 - x2 * y1) for (x1, y1), (x2, y2) in zip(o, o[1:] + o[:1])) / (6 * a)
        if in_ring(cx, cy, o) and not any(in_ring(cx, cy, h) for h in p[1:]): return cx, cy
        lo, hi = min(y for _, y in o), max(y for _, y in o)
        for f in (0.5, 0.4, 0.6, 0.3, 0.7, 0.2, 0.8):
            y = lo + (hi - lo) * f
            xs = sorted(x1 + (y - y1) * (x2 - x1) / (y2 - y1) for r in p for (x1, y1), (x2, y2) in zip(r, r[1:] + r[:1])
                        if (y1 > y) != (y2 > y))
            spans = sorted(((b - a_, (a_ + b) / 2) for a_, b in zip(xs[::2], xs[1::2])), reverse=True)
            if spans and in_ring(spans[0][1], y, o): return spans[0][1], y
        raise ValueError("no interior point found")

    def inside(self, code, lat, lon): return code in self.polys and self._in(code, lon * KX, lat * KY)

    def snap(self, code, lat, lon):
        """(lat, lon, metres moved). Unchanged if already inside its own ward (or ward unknown). Otherwise: nearest
        point on the ward boundary (outer rings and holes), nudged NUDGE_M inward, then stepped towards the ward's
        interior point until the rounded result tests inside."""
        if lat is None or code not in self.polys or self.inside(code, lat, lon): return lat, lon, 0.0
        x, y = lon * KX, lat * KY
        best = None
        for p in self.polys[code]:
            for r in p:
                for (x1, y1), (x2, y2) in zip(r, r[1:] + r[:1]):
                    dx, dy = x2 - x1, y2 - y1
                    t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy))) if dx or dy else 0.0
                    q = (x1 + t * dx, y1 + t * dy)
                    d = math.hypot(q[0] - x, q[1] - y)
                    if best is None or d < best[0]: best = (d, q)
        d, (qx, qy) = best
        nx, ny = (qx + (qx - x) / d * NUDGE_M, qy + (qy - y) / d * NUDGE_M) if d else (qx, qy)
        rx, ry = self.rep[code]
        while True:
            la, lo = round(ny / KY, 6), round(nx / KX, 6)
            if self.inside(code, la, lo): break
            g = math.hypot(rx - nx, ry - ny)
            if g <= STEP_M: la, lo = round(ry / KY, 6), round(rx / KX, 6); break
            nx, ny = nx + (rx - nx) / g * STEP_M, ny + (ry - ny) / g * STEP_M
        return la, lo, math.hypot(lo * KX - x, la * KY - y)


def in_bbox(lat, lon): return BBOX[0] <= lat <= BBOX[1] and BBOX[2] <= lon <= BBOX[3]

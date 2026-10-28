"""Natural Earth 110m land -> one simplified SVG path, equirectangular."""
import json, sys

src, dst = sys.argv[1], sys.argv[2]
LAT_MIN, LAT_MAX, W = -58.0, 84.0, 1000.0
H = W * (LAT_MAX - LAT_MIN) / 360.0

def project(lon, lat):
    x = (lon + 180.0) / 360.0 * W
    y = (LAT_MAX - lat) / (LAT_MAX - LAT_MIN) * H
    return x, y

def perp(p, a, b):
    (x, y), (x1, y1), (x2, y2) = p, a, b
    dx, dy = x2 - x1, y2 - y1
    if dx == dy == 0: return ((x-x1)**2 + (y-y1)**2) ** 0.5
    t = max(0, min(1, ((x-x1)*dx + (y-y1)*dy) / (dx*dx + dy*dy)))
    return ((x - (x1+t*dx))**2 + (y - (y1+t*dy))**2) ** 0.5

def simplify(pts, tol):                      # Douglas-Peucker, iterative
    if len(pts) < 3: return pts
    keep = [False]*len(pts); keep[0] = keep[-1] = True
    stack = [(0, len(pts)-1)]
    while stack:
        i, j = stack.pop()
        if j <= i+1: continue
        dmax, idx = 0.0, i
        for k in range(i+1, j):
            d = perp(pts[k], pts[i], pts[j])
            if d > dmax: dmax, idx = d, k
        if dmax > tol:
            keep[idx] = True
            stack += [(i, idx), (idx, j)]
    return [p for p, k in zip(pts, keep) if k]

rings = []
for feat in json.load(open(src))['features']:
    g = feat['geometry']
    polys = [g['coordinates']] if g['type'] == 'Polygon' else g['coordinates']
    for poly in polys:
        for ring in poly:
            pts = [project(lon, lat) for lon, lat in ring
                   if -180 <= lon <= 180 and LAT_MIN <= lat <= LAT_MAX]
            if len(pts) < 4: continue
            pts = simplify(pts, 0.45)
            if len(pts) >= 4:
                rings.append(pts)

f = lambda v: ('%.1f' % v).rstrip('0').rstrip('.')
parts = []
for r in rings:
    parts.append('M' + ' L'.join(f(x) + ',' + f(y) for x, y in r) + 'Z')
path = ''.join(parts)
open(dst, 'w').write(path)
print('rings: %d   points: %d   path: %d bytes   viewBox 0 0 %g %.1f'
      % (len(rings), sum(len(r) for r in rings), len(path), W, H))

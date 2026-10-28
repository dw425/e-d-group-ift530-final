# Vendored map data

`world_land_110m.path` is the Natural Earth **110m physical land** layer,
projected to equirectangular and simplified to a single SVG path by
`tools/mkland.py`. It is vendored so `tools/dashboard_html.py` builds
offline and always draws the same map.

Natural Earth is public domain. Source data:
<https://github.com/martynafford/natural-earth-geojson> (110m/physical/
ne_110m_land.json), itself a GeoJSON rendering of
<https://www.naturalearthdata.com/>.

118 rings, 3,070 points. viewBox `0 0 1000 394.4`, covering longitude
-180..180 and latitude -58..84 — Antarctica is cropped, which is normal
for a traffic map and keeps the populated latitudes large.

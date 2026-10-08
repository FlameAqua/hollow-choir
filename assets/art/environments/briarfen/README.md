# Briarfen combat environments

All runtime backgrounds live directly in this directory. Names are
`briarfen_marsh_day_N.png` and `briarfen_marsh_night_N.png`; the same number identifies the same
composition in both lighting sets. 1 is the original marsh, 2 the bell causeway, 3 the root hollow.
Use numeric order, not lexicographic order when N reaches 10. No nested alternatives folders.

`catalog.json` records dimensions/hashes, paired lighting and prompt provenance. Day/night is visual
only: no simulation clock, condition, weather rule or enemy behavior is inferred. The existing default
is night 1. Use the same stage crop, open foreground footing and actor sizes for every image.

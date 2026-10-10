"""Author continuous control strips. End caps stay native; the center stretches without repeats."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets/art/global/ui/material_v04/textures"
ROOT.mkdir(parents=True, exist_ok=True)


def strip(name, length, thickness, vertical=False, raised=False):
    # Draw in horizontal coordinates, then rotate for a vertical strip. No repeating pattern.
    width, height = (thickness, length) if vertical else (length, thickness)
    light, middle, dark = ("#b6ab7c", "#655f43", "#343f32") if raised else ("#69705a", "#28352f", "#111d1a")
    transform = f'translate({thickness} 0) rotate(90)' if vertical else ""
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<defs>
 <linearGradient id="metal" x1="0" y1="0" x2="0" y2="1" gradientUnits="objectBoundingBox"><stop stop-color="{light}"/><stop offset=".22" stop-color="{middle}"/><stop offset=".72" stop-color="{dark}"/><stop offset="1" stop-color="#0d1715"/></linearGradient>
 <linearGradient id="wear"><stop stop-color="#a49c6d" stop-opacity=".12"/><stop offset=".48" stop-color="#dfd4a0" stop-opacity=".28"/><stop offset="1" stop-color="#8e9373" stop-opacity=".08"/></linearGradient>
</defs>
<g transform="{transform}">
 <path d="M4 0H{length-4}L{length} 4V{thickness-4}L{length-4} {thickness}H4L0 {thickness-4}V4Z" fill="#0b1412"/>
 <path d="M4 1H{length-4}L{length-1} 4V{thickness-4}L{length-4} {thickness-1}H4L1 {thickness-4}V4Z" fill="url(#metal)" stroke="#5e644c" stroke-width="1"/>
 <path d="M8 4H{length-8}V{thickness-4}H8Z" fill="url(#wear)"/>
 <path d="M8 3H{length-8}" stroke="#d1c89c" stroke-opacity=".34"/>
 <path d="M8 {thickness-3}H{length-8}" stroke="#0c1613" stroke-opacity=".8"/>
 <path d="M5 5V{thickness-5}M{length-5} 5V{thickness-5}" stroke="#c7bd8a" stroke-opacity=".5"/>
</g></svg>
'''
    (ROOT / f"{name}.svg").write_text(svg, encoding="utf-8")


strip("slider_track", 320, 24)
strip("slider_fill", 320, 24, raised=True)
strip("scroll_track", 320, 16, vertical=True)
strip("scroll_thumb", 96, 16, vertical=True, raised=True)
strip("h_scroll_track", 320, 16)
strip("h_scroll_thumb", 96, 16, raised=True)

"""Original stepped SVG additions to Hollow Choir's existing native item-icon family."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'assets/art/global/ui/journey_v05/icons'
OUT.mkdir(parents=True, exist_ok=True)
shapes = {
 'kit': '<path fill="#73583b" d="M7 17h34v24H7z"/><path fill="#b69a61" d="M17 9h14v8h-4v-4h-6v4h-4zM7 22h34v4H7zM21 20h6v10h-6z"/>',
 'merciful_grip': '<path fill="#a2aaa0" d="M29 4h6v17h-6zM20 20h23v5H20z"/><path fill="#765039" d="M27 25h9v17h-9z"/><path fill="#c6ad7e" d="M27 27h9v3h-9zM27 33h9v3h-9zM27 39h9v3h-9z"/><path fill="#94c89b" d="M8 9h5v5h5v5h-5v5H8v-5H3v-5h5z"/>',
 'hollow_echo': '<path fill="#a2aaa0" d="M21 4h6v18h-6zM13 22h22v5H13z"/><path fill="#73583b" d="M20 27h8v16h-8z"/><path fill="none" stroke="#bdb69e" stroke-width="3" d="M10 9l-4 5v10l4 5M36 9l5 5v10l-5 5"/>',
 'anvil': '<path fill="#717a74" d="M5 12h38v9l-12 5H20L8 21H5z"/><path fill="#3c4440" d="M20 25h11v9H20zM14 34h24v7H14z"/><path fill="#c1bda7" d="M5 12h38v4H5z"/>',
 'stillroom': '<path fill="#ad8252" d="M15 9h12v7l7 7v14l-6 5H13l-6-5V23l8-7z"/><path fill="#d0b480" d="M14 7h14v5H14zM13 24h5v9h-5z"/><path fill="none" stroke="#ad8252" stroke-width="4" d="M27 9h9v17h7v14"/>',
 'lock': '<path fill="none" stroke="#8d856c" stroke-width="4" d="M15 23V12l5-5h8l5 5v11"/><path fill="#625e50" d="M10 21h28v22H10z"/><path fill="#bcb294" d="M22 28h4v8h-4z"/>',
 'save': '<path fill="#7f8c76" d="M8 6h28l6 6v30H8z"/><path fill="#d3c7a4" d="M15 6h18v12H15zM14 26h22v16H14z"/><path fill="#39483f" d="M27 8h4v8h-4zM18 30h14v3H18zM18 36h14v3H18z"/>',
 'help': '<path fill="#d3c7a4" d="M15 8h18l6 6v9l-12 8v4h-6v-8l12-8v-3l-3-3H18l-3 4H9v-3zM21 39h6v6h-6z"/>',
 'empty': '<path fill="none" stroke="#8d856c" stroke-width="3" d="M8 8h32v32H8z"/><path fill="#8d856c" d="M14 22h20v4H14z"/>',
}
for name, liquid in [('mending_draught','#9c574b'),('fen_water_flask','#699a9c'),('clotting_salve','#8b9770'),('focus_tincture','#c7ad67')]:
    shapes[name] = f'<path fill="#aaa38d" d="M18 5h12v12l7 8v16H11V25l7-8z"/><path fill="{liquid}" d="M15 27h18v11H15z"/><path fill="#73583b" d="M17 4h14v7H17z"/><path fill="#e1d8bb" d="M15 24h4v11h-4z"/>'
for name, content in shapes.items():
    (OUT / f'{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><g stroke="#171a17" stroke-width="2" stroke-linejoin="miter">{content}</g></svg>\n', encoding='utf-8')
print(f'{len(shapes)} original native icons written')

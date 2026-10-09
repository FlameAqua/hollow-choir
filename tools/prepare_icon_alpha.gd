extends SceneTree
## Adds transparency outside the app icon's rounded bronze frame (Adrian, 9 October 2026) and
## writes hollow_choir_v02.png / .ico beside the untouched v01 files.
##
## The background is the near-black region connected to the source image's border (flood fill), so
## dark pixels inside the frame (the mask's eye holes, the marsh) stay opaque. Every RGB pixel is
## copied unchanged from the matching v01 PNG / ICO frame; only alpha is added, as the exact area
## coverage of the full-resolution mask (summed-area table, no resampling halos).
##
##   python tools/qa_godot.py --headless --script res://tools/prepare_icon_alpha.gd [-- --preview=<dir>]

const ICON := "res://assets/art/global/icon/"
const SOURCE := ICON + "sources/hollow_choir_v01.png"
## Darkest channel value still treated as background (source corners are black).
const THRESHOLD := 40


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	source.convert(Image.FORMAT_RGB8)
	var size := source.get_width()
	var background := _background(source)
	var table := _summed_area(background, size)
	var transparent := 0
	for value in background:
		transparent += value
	print("Background: %d of %d source pixels (%.2f%%)" % [transparent, size * size, 100.0 * transparent / (size * size)])
	var png := Image.load_from_file(ICON + "hollow_choir_v01.png")
	var icon := _with_alpha(png, table, size)
	assert(icon.save_png(ICON + "hollow_choir_v02.png") == OK)
	var frames: Array[Image] = []
	for frame in _read_ico(ICON + "hollow_choir_v01.ico"):
		frames.append(_with_alpha(frame, table, size))
	_write_ico(ICON + "hollow_choir_v02.ico", frames)
	for frame in frames:
		print("%dpx: corner alpha %d, centre alpha %d" % [frame.get_width(), frame.get_pixel(0, 0).a8, frame.get_pixel(frame.get_width() / 2, frame.get_height() / 2).a8])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="):
			_preview(icon, arg.trim_prefix("--preview="))
	quit()


## 1 = background (near-black and connected to the border), 0 = the icon itself.
func _background(source: Image) -> PackedByteArray:
	var size := source.get_width()
	var data := source.get_data()
	var result := PackedByteArray()
	result.resize(size * size)
	var queue := PackedInt32Array()
	for i in size:
		for index in [i, (size - 1) * size + i, i * size, i * size + size - 1]:
			if result[index] == 0 and _dark(data, index):
				result[index] = 1
				queue.append(index)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var x := index % size
		var y := index / size
		for next in [index - 1 if x > 0 else -1, index + 1 if x < size - 1 else -1, index - size if y > 0 else -1, index + size if y < size - 1 else -1]:
			if next >= 0 and result[next] == 0 and _dark(data, next):
				result[next] = 1
				queue.append(next)
	return result


func _dark(data: PackedByteArray, index: int) -> bool:
	return maxi(data[index * 3], maxi(data[index * 3 + 1], data[index * 3 + 2])) <= THRESHOLD


## (size + 1)² table of foreground counts.
func _summed_area(background: PackedByteArray, size: int) -> PackedInt32Array:
	var stride := size + 1
	var table := PackedInt32Array()
	table.resize(stride * stride)
	for y in size:
		var row := 0
		for x in size:
			row += 1 - background[y * size + x]
			table[(y + 1) * stride + x + 1] = table[y * stride + x + 1] + row
	return table


## Alpha = share of foreground source pixels whose centres fall inside each target pixel.
func _with_alpha(image: Image, table: PackedInt32Array, size: int) -> Image:
	var result := image.duplicate() as Image
	result.convert(Image.FORMAT_RGBA8)
	var target := result.get_width()
	var scale := float(size) / target
	var stride := size + 1
	var bounds := PackedInt32Array()
	for i in target + 1:
		bounds.append(clampi(ceili(i * scale - 0.5), 0, size))
	for y in target:
		for x in target:
			var x0 := bounds[x]
			var x1 := bounds[x + 1]
			var y0 := bounds[y]
			var y1 := bounds[y + 1]
			var area := maxi(1, (x1 - x0) * (y1 - y0))
			var inside := table[y1 * stride + x1] - table[y0 * stride + x1] - table[y1 * stride + x0] + table[y0 * stride + x0]
			var color := result.get_pixel(x, y)
			color.a8 = roundi(255.0 * inside / area)
			result.set_pixel(x, y, color)
	return result


func _read_ico(path: String) -> Array[Image]:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null)
	file.get_16()
	assert(file.get_16() == 1, "an icon file")
	var count := file.get_16()
	var entries: Array[Vector2i] = []
	for i in count:
		file.seek(6 + 16 * i + 8)
		var length := file.get_32()
		var offset := file.get_32()
		entries.append(Vector2i(offset, length))
	var images: Array[Image] = []
	for entry in entries:
		file.seek(entry.x)
		var image := Image.new()
		assert(image.load_png_from_buffer(file.get_buffer(entry.y)) == OK, "PNG-compressed ICO frames")
		images.append(image)
	return images


func _write_ico(path: String, frames: Array[Image]) -> void:
	var buffers: Array[PackedByteArray] = []
	for frame in frames:
		buffers.append(frame.save_png_to_buffer())
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_16(0)
	file.store_16(1)
	file.store_16(frames.size())
	var offset := 6 + 16 * frames.size()
	for i in frames.size():
		var side := frames[i].get_width()
		file.store_8(0 if side >= 256 else side)
		file.store_8(0 if side >= 256 else side)
		file.store_8(0)
		file.store_8(0)
		file.store_16(1)
		file.store_16(32)
		file.store_32(buffers[i].size())
		file.store_32(offset)
		offset += buffers[i].size()
	for buffer in buffers:
		file.store_buffer(buffer)
	file.close()


## The icon composited over light and dark grounds, enlarged 2x without filtering, for review.
func _preview(icon: Image, folder: String) -> void:
	var side := icon.get_width()
	var sheet := Image.create_empty(side * 2, side, false, Image.FORMAT_RGBA8)
	sheet.fill_rect(Rect2i(0, 0, side, side), Color(0.93, 0.92, 0.88))
	sheet.fill_rect(Rect2i(side, 0, side, side), Color(0.12, 0.13, 0.16))
	sheet.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i.ZERO)
	sheet.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i(side, 0))
	sheet.resize(side * 4, side * 2, Image.INTERPOLATE_NEAREST)
	assert(sheet.save_png(folder.path_join("icon_v02_preview.png")) == OK)

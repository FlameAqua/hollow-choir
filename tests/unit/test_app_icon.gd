extends TestCase
## App icon v02 (Adrian, 9 October 2026): the black background outside the rounded bronze frame is
## transparent, everything inside it (including the mask's dark eye holes) stays opaque, and no
## colour changed from v01. Built by tools/prepare_icon_alpha.gd.

const ICON := "res://assets/art/global/icon/"


func _read_ico(path: String) -> Array[Image]:
	var images: Array[Image] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return images
	file.get_16()
	if file.get_16() != 1:
		return images
	var count := file.get_16()
	var entries: Array[Vector2i] = []
	for i in count:
		file.seek(6 + 16 * i + 8)
		var length := file.get_32()
		entries.append(Vector2i(file.get_32(), length))
	for entry in entries:
		file.seek(entry.x)
		var image := Image.new()
		if image.load_png_from_buffer(file.get_buffer(entry.y)) == OK:
			images.append(image)
	return images


## Corners transparent, the inner 76% opaque, RGB identical to the v01 image of the same size.
func _check(image: Image, original: Image, label: String) -> void:
	var side := image.get_width()
	assert_true(image.detect_alpha() != Image.ALPHA_NONE, label + " has alpha")
	for corner in [Vector2i(0, 0), Vector2i(side - 1, 0), Vector2i(0, side - 1), Vector2i(side - 1, side - 1)]:
		assert_lte(image.get_pixelv(corner).a8, 16, "%s corner %s is transparent" % [label, corner])
	var inner := Rect2i(Vector2i.ONE * roundi(side * 0.12), Vector2i.ONE * (side - 2 * roundi(side * 0.12)))
	var opaque := true
	var same := true
	original.convert(Image.FORMAT_RGBA8)
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			opaque = opaque and image.get_pixel(x, y).a8 == 255
	for y in side:
		for x in side:
			var a := image.get_pixel(x, y)
			var b := original.get_pixel(x, y)
			same = same and a.r8 == b.r8 and a.g8 == b.g8 and a.b8 == b.b8
	assert_true(opaque, label + ": everything inside the frame stays opaque")
	assert_true(same, label + ": colours are unchanged from v01")


func test_project_uses_the_transparent_icon() -> void:
	var png: String = ProjectSettings.get_setting("application/config/icon")
	var ico: String = ProjectSettings.get_setting("application/config/windows_native_icon")
	assert_eq(png, ICON + "hollow_choir_v02.png")
	assert_eq(ico, ICON + "hollow_choir_v02.ico")
	assert_true(ResourceLoader.exists(png), "the PNG icon is imported")
	assert_true(FileAccess.file_exists(ico))


## The file itself, not the imported texture (import's fix_alpha_border recolours hidden pixels).
func _png(path: String) -> Image:
	var image := Image.new()
	image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	return image


func test_icon_png_is_transparent_outside_the_frame_only() -> void:
	var image := _png(ICON + "hollow_choir_v02.png")
	var original := _png(ICON + "hollow_choir_v01.png")
	assert_eq(image.get_size(), Vector2i(256, 256))
	image.convert(Image.FORMAT_RGBA8)
	_check(image, original, "256px PNG")


func test_every_ico_size_is_transparent_outside_the_frame_only() -> void:
	var frames := _read_ico(ICON + "hollow_choir_v02.ico")
	var originals := _read_ico(ICON + "hollow_choir_v01.ico")
	var sizes: Array[int] = []
	for frame in frames:
		sizes.append(frame.get_width())
	assert_eq(sizes, [16, 24, 32, 48, 64, 128, 256] as Array[int], "the same seven Windows sizes")
	assert_eq(originals.size(), frames.size())
	for i in mini(frames.size(), originals.size()):
		frames[i].convert(Image.FORMAT_RGBA8)
		_check(frames[i], originals[i], "%dpx ICO frame" % frames[i].get_width())

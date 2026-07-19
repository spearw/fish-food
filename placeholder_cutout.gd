extends SceneTree
## Placeholder-art cutout tool: turns a downloaded creature photo/plate into a game-ready sprite.
## Flood-fills the background to transparent from the image border, autocrops, and downscales.
## The output is DELIBERATELY a recognizable photo/illustration -- placeholder art should be easy
## to spot for replacement (see docs/placeholder_art.md).
##
## Usage (headless, from the project root):
##   Godot --headless --script res://placeholder_cutout.gd -- \
##       --in=C:/path/source.jpg --out=C:/path/sprite.png [--tol=0.14] [--max=120] [--crop-bottom=0]
##
## tol: color distance to the border average that counts as background (0-1 per channel space).
## max: longest output dimension in px. crop-bottom: px cut off first (caption strips on plates).

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var in_path: String = args.get("in", "")
	var out_path: String = args.get("out", "")
	var tol: float = float(args.get("tol", "0.14"))
	var max_dim: int = int(args.get("max", "120"))
	var crop_bottom: int = int(args.get("crop-bottom", "0"))
	if in_path == "" or out_path == "":
		print("CUTOUT ERROR: --in and --out are required")
		quit(1)
		return

	var img := Image.new()
	var err := img.load(in_path)
	if err != OK:
		print("CUTOUT ERROR: could not load ", in_path)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	if crop_bottom > 0 and crop_bottom < img.get_height():
		img = img.get_region(Rect2i(0, 0, img.get_width(), img.get_height() - crop_bottom))

	var w := img.get_width()
	var h := img.get_height()

	# Average border color = the background reference. Alpha comes along: a source that is ALREADY
	# transparent at the border (SVG renders) switches the fill test to alpha, because its opaque
	# black linework would otherwise match a black "background color" and get eaten.
	var sum := Vector3.ZERO
	var alpha_sum := 0.0
	var n := 0
	for x in range(w):
		for y in [0, h - 1]:
			var c := img.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			alpha_sum += c.a
			n += 1
	for y in range(h):
		for x in [0, w - 1]:
			var c := img.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			alpha_sum += c.a
			n += 1
	var bg := sum / float(n)
	var alpha_mode: bool = alpha_sum / float(n) < 0.5

	# BFS flood fill from every border pixel that reads as background.
	var visited := PackedByteArray()
	visited.resize(w * h)
	var queue: Array[Vector2i] = []
	for x in range(w):
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, h - 1))
	for y in range(h):
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(w - 1, y))
	var cleared := 0
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		var idx := p.y * w + p.x
		if visited[idx] == 1:
			continue
		visited[idx] = 1
		var c := img.get_pixelv(p)
		if alpha_mode:
			if c.a >= 0.5:
				continue
		elif Vector3(c.r, c.g, c.b).distance_to(bg) > tol:
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		cleared += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if q.x >= 0 and q.x < w and q.y >= 0 and q.y < h and visited[q.y * w + q.x] == 0:
				queue.append(q)

	# Autocrop to the remaining content, downscale, save.
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		print("CUTOUT ERROR: everything was background (tol too high?)")
		quit(1)
		return
	img = img.get_region(used)
	var scale_f: float = float(max_dim) / float(maxi(img.get_width(), img.get_height()))
	if scale_f < 1.0:
		img.resize(int(img.get_width() * scale_f), int(img.get_height() * scale_f),
			Image.INTERPOLATE_LANCZOS)
	err = img.save_png(out_path)
	if err != OK:
		print("CUTOUT ERROR: could not save ", out_path)
		quit(1)
		return
	print("CUTOUT OK: %s -> %s (%dx%d, cleared %d px, bg %.2f/%.2f/%.2f)" % [
		in_path.get_file(), out_path, img.get_width(), img.get_height(), cleared, bg.x, bg.y, bg.z])
	quit(0)

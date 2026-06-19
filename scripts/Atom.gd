extends Area2D
# 作者:CK

# ============================================================
# Atom.gd - 原子节点（数据 + 自绘制 + 价态显示）
# ============================================================

var id: int = -1
var symbol: String = "C"
var valence_max: int = 4
var valence_used: int = 0
var neighbors: Array = []
var draw_skeletal: bool = false

const RADIUS: float = 20.0


func setup(atom_symbol: String, atom_id: int):
	symbol = atom_symbol
	id = atom_id
	valence_max = Global.get_valence(symbol)

	var col = $CollisionShape2D
	if col and col.shape:
		col.shape.radius = RADIUS

	queue_redraw()


func _draw():
	var color = Global.get_color(symbol)
	var font = ThemeDB.fallback_font
	if font == null:
		return

	if draw_skeletal:
		if symbol == "H":
			draw_circle(Vector2.ZERO, 9, Color.WHITE)
			var fs = 13
			var tw = font.get_string_size("H", HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			draw_string(font, Vector2(-tw / 2.0, fs / 3.0),
				"H", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.BLACK)
		elif symbol == "C":
			draw_circle(Vector2.ZERO, 2, Color.BLACK)
			if Global.is_truly_chiral(self):
				var rs = Global.calc_rs(self)
				if rs != "":
					var label = "*" + rs
					draw_string(font, Vector2(6, -6),
						label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.2, 0.8))
				if Global.show_chiral:
					_draw_wedges()
		else:
			draw_circle(Vector2.ZERO, 11, Color.WHITE)
			var fs = 18
			var tw = font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			draw_string(font, Vector2(-tw / 2.0, fs / 3.0),
				symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, color)
		return

	# 原子主体
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 32, color.darkened(0.35), 2.0)

	# 元素符号
	var font_size = 14
	var txt_color = Color.BLACK if color.v > 0.5 else Color.WHITE
	var tw = font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	draw_string(font, Vector2(-tw / 2.0, font_size / 3.0),
		symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, txt_color)

	# 价态指示灯（绕圆周）
	if valence_max > 1:
		for i in range(valence_max):
			var angle = -PI / 2.0 + TAU * float(i) / float(valence_max)
			var p = Vector2(cos(angle) * (RADIUS + 6), sin(angle) * (RADIUS + 6))
			if i < valence_used:
				draw_circle(p, 3.0, Color.YELLOW)
			else:
				draw_circle(p, 2.0, Color(0.3, 0.3, 0.3, 0.35))

	# 键计数文字
	if neighbors.size() > 0:
		var cnt = str(neighbors.size()) + "/" + str(valence_max)
		var cw = font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_CENTER, -1, 9).x
		draw_string(font, Vector2(-cw / 2.0, -RADIUS - 10),
			cnt, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.4, 0.4, 0.4))

	# 手性碳标记 * + R/S
	if symbol == "C" and valence_used == 4 and Global.show_chiral and Global.is_truly_chiral(self):
		var rs = Global.calc_rs(self)
		if rs != "":
			var label = "*" + rs
			var sw = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
			draw_string(font, Vector2(RADIUS + 4, -8),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.2, 0.8))


func _draw_wedges():
	if not Global.is_truly_chiral(self): return
	var nbs = []
	for nb_id in neighbors:
		var nb = null
		for ga in Global.atoms:
			if is_instance_valid(ga) and ga.id == nb_id:
				nb = ga; break
		if nb: nbs.append({"atom": nb, "pri": Global._nb_pri(nb, id)})
	nbs.sort_custom(func(x, y): return x.pri < y.pri)
	nbs.sort_custom(func(x, y): return x.pri < y.pri)
	for i in range(4):
		var nb_pos = nbs[i].atom.position - position
		var dir = nb_pos.normalized()
		var half = Vector2(-dir.y, dir.x) * 6
		var p1 = half
		var p2 = -half
		var p3 = nb_pos
		if i == 0:
			for k in range(1, 6):
				var t = float(k) / 6.0
				var a = p1.lerp(p3, t)
				var b = p2.lerp(p3, t)
				draw_line(a, b, Color.BLACK, 1.0)
		elif i == 3:
			draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color.BLACK)

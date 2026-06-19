extends Node2D
class_name CanvasWorld
# 作者:CK

enum ViewMode { VIEW_2D, VIEW_3D, VIEW_SKELETAL }

signal atom_changed()
signal show_error(title: String, message: String)
signal request_context_menu()

const ATOM_SCENE  = preload("res://scenes/Atom.tscn")
const GRID_SIZE   = 40
const DRAG_THRESH = 5.0
const BOND_LEN    = 80.0
const RING_R      = 70.0
const RING_R5     = 65.0
var bg_color   = Color(0.88, 0.88, 0.88)
var grid_color = Color(0.70, 0.70, 0.70, 0.35)

var spawn_index: int = 0
var view_mode: ViewMode = ViewMode.VIEW_2D

# single atom interaction
var _pressed_atom: Area2D = null
var _pressed_pos:   Vector2 = Vector2.ZERO
var _dragging:      bool    = false
var _drag_offset:   Vector2 = Vector2.ZERO
var _drag_bases:    Dictionary = {}
var _drag_h_bases:  Dictionary = {}   

# 多选 + 框选
var selected_atoms: Array = []
var _box_start:   Vector2 = Vector2.ZERO
var _box_end:     Vector2 = Vector2.ZERO
var _boxing:      bool    = false

var _camera: Camera2D
var _panning: bool = false
var _pan_start_mouse: Vector2
var _pan_start_cam: Vector2


func _ready():
	get_viewport().size_changed.connect(queue_redraw.unbind(1))
	_camera = Camera2D.new()
	_camera.enabled = true
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_camera.position = Vector2(442, 360)
	add_child(_camera)
	move_child(_camera, 0)


# ============================================================
# 绘制
# ============================================================

func _draw():
	var sz = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, sz), bg_color)
	# 框选矩形
	if _boxing:
		var r = Rect2(_box_start, _box_end - _box_start).abs()
		draw_rect(r, Color(0.3, 0.7, 1.0, 0.15), true)
		draw_rect(r, Color(0.3, 0.7, 1.0, 0.6),  false)


func _process(_dt):
	var mp = get_global_mouse_position()

	# 中键平移
	if _panning:
		_camera.position = _pan_start_cam + (_pan_start_mouse - get_viewport().get_mouse_position()) / _camera.zoom
		queue_redraw()
		return

	# 拖拽阈值
	if _pressed_atom and not _dragging and is_instance_valid(_pressed_atom):
		if mp.distance_to(_pressed_pos) > DRAG_THRESH:
			_dragging = true
			_drag_offset = _pressed_pos - _pressed_atom.position

			# 如果被拖原子属于多选，整体移动
			if _pressed_atom in selected_atoms:
				_drag_bases.clear()
				_drag_h_bases.clear()
				for a in selected_atoms:
					if is_instance_valid(a):
						_drag_bases[a.id] = a.position
			else:
				_clear_selection()

			_drag_h_bases.clear()
			var drag_set = selected_atoms if _pressed_atom in selected_atoms else [_pressed_atom]
			for a in drag_set:
				if not is_instance_valid(a): continue
				for nb_id in a.neighbors:
					var nb = _find(nb_id)
					if nb and nb.symbol == "H":
						_drag_h_bases[nb.id] = nb.position

			_pressed_atom.modulate = Color(1.0, 1.0, 0.5)
			move_child(_pressed_atom, get_child_count() - 1)

	# 拖拽跟随
	if _dragging and _pressed_atom and is_instance_valid(_pressed_atom):
		var delta = mp - _drag_offset - _pressed_atom.position
		if _pressed_atom in selected_atoms and selected_atoms.size() > 1:
			for a in selected_atoms:
				if is_instance_valid(a) and a.has_method("setup"):
					a.position = _drag_bases.get(a.id, a.position) + delta
		else:
			_pressed_atom.position = mp - _drag_offset
		for hid in _drag_h_bases:
			var h = _find(hid)
			if is_instance_valid(h) and h.symbol == "H":
				h.position = _drag_h_bases[hid] + delta

	# 框选更新
	if _boxing:
		_box_end = mp
		queue_redraw()

	# 更新键线
	for bond in Global.bonds:
		var a1 = _find(bond.id1)
		var a2 = _find(bond.id2)
		if a1 and a2:
			if is_instance_valid(bond.get("line_ref")):
				bond.line_ref.points = [a1.position, a2.position]
			if is_instance_valid(bond.get("line_ref2")):
				var off = _perp(a1.position, a2.position)
				bond.line_ref2.points = [a1.position + off, a2.position + off]
			if is_instance_valid(bond.get("line_ref3")):
				var off = _perp(a1.position, a2.position)
				bond.line_ref3.points = [a1.position - off, a2.position - off]


# ============================================================
# 输入
# ============================================================

func _input(event: InputEvent):
	if view_mode != ViewMode.VIEW_2D:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_camera.zoom = (_camera.zoom * 1.1).clamp(Vector2(0.25, 0.25), Vector2(3.0, 3.0))
				queue_redraw()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_camera.zoom = (_camera.zoom * 0.9).clamp(Vector2(0.25, 0.25), Vector2(3.0, 3.0))
				queue_redraw()
			elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
				show_error.emit("视图限制", "请切换到2D视图进行操作。")
		return

	# 缩放
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom = (_camera.zoom * 1.1).clamp(Vector2(0.25, 0.25), Vector2(3.0, 3.0))
			queue_redraw(); return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom = (_camera.zoom * 0.9).clamp(Vector2(0.25, 0.25), Vector2(3.0, 3.0))
			queue_redraw(); return

	# 中键平移
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_panning = true
				_pan_start_mouse = event.position
				_pan_start_cam = _camera.position
			else:
				_panning = false
			return

	if event is InputEventMouseButton:
		var mpos = get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed_pos  = mpos
				_pressed_atom = _hit(mpos)
				_dragging     = false
				if _pressed_atom == null:
					# 开始框选
					_box_start = mpos
					_box_end   = mpos
					_boxing    = true
					_clear_selection()
				else:
					_boxing = false
			else:
				_boxing = false
				queue_redraw()
				var dist = mpos.distance_to(_pressed_pos)
				if _dragging:
					_finish_drag()
				elif dist < DRAG_THRESH and _pressed_atom:
					# 短击
					if Input.is_key_pressed(KEY_SHIFT):
						_toggle_selection(_pressed_atom)
					elif selected_atoms.size() == 1 and selected_atoms[0] != _pressed_atom:
						var a = selected_atoms[0]
						_clear_selection()
						_try_bond(a, _pressed_atom)
					elif selected_atoms.size() == 0:
						_toggle_selection(_pressed_atom)
					else:
						_clear_selection()
						_toggle_selection(_pressed_atom)
				elif _box_start.distance_to(_box_end) > 3.0:
					_apply_box_select()
				_pressed_atom = null
				_dragging     = false

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var hit = _hit(mpos)
			if hit:
				if selected_atoms.is_empty():
					_toggle_selection(hit)
				request_context_menu.emit()
			else:
				_clear_selection()



func _toggle_selection(atom: Area2D):
	if atom in selected_atoms:
		selected_atoms.erase(atom)
		atom.modulate = Color.WHITE
	else:
		selected_atoms.append(atom)
		atom.modulate = Color(0.5, 1.0, 0.5)  # 绿色选中


func _clear_selection():
	for a in selected_atoms:
		if is_instance_valid(a):
			a.modulate = Color.WHITE
	selected_atoms.clear()


func _apply_box_select():
	var rect = Rect2(_box_start, _box_end - _box_start).abs()
	_clear_selection()
	for a in Global.atoms:
		if is_instance_valid(a) and rect.has_point(a.position):
			_toggle_selection(a)


func delete_selected():
	for a in selected_atoms.duplicate():
		if is_instance_valid(a):
			_delete_atom(a)
	_clear_selection()
	atom_changed.emit()


func unlink_selected():
	_unlink_internal()
	atom_changed.emit()


func clear_selection():
	_clear_selection()


func saturate_valence():
	for a in selected_atoms:
		if not is_instance_valid(a):
			continue
		var need = a.valence_max - a.valence_used
		for _i in range(need):
			var h = _spawn("H", a.position + Vector2(BOND_LEN, 0))
			_create_bond(a, h, 1)
	_refresh_h_visibility()
	_relax_structure()
	atom_changed.emit()


func set_view_mode(mode: ViewMode):
	view_mode = mode
	if mode == ViewMode.VIEW_SKELETAL:
		for a in Global.atoms:
			if not is_instance_valid(a): continue
			if a.symbol == "C":
				var chiral = _is_chiral(a)
				a.visible = chiral
				a.draw_skeletal = chiral
				var col = a.get_node_or_null("CollisionShape2D")
				if col: col.disabled = true
				if chiral: a.queue_redraw()
			elif a.symbol == "H":
				var show = false
				for nb_id in a.neighbors:
					var nb = _find(nb_id)
					if nb and nb.symbol != "C":
						show = true; break
					if nb and nb.symbol == "C" and _is_chiral(nb):
						show = true; break
				a.visible = show
				a.draw_skeletal = show
				var col = a.get_node_or_null("CollisionShape2D")
				if col: col.disabled = !show
				if show: a.queue_redraw()
			else:
				a.visible = true
				a.draw_skeletal = true
				var col = a.get_node_or_null("CollisionShape2D")
				if col: col.disabled = false
				a.queue_redraw()
		for bond in Global.bonds:
			var a1 = _find(bond.id1); var a2 = _find(bond.id2)
			var vis = (a1 and a1.visible) or (a2 and a2.visible)
			if not vis:
				vis = a1 and a2 and a1.symbol == "C" and a2.symbol == "C"
			# 隐藏手性C的楔形键（由Atom自绘代替）
			if vis and Global.show_chiral:
				for a in [a1, a2]:
					if a and a.symbol == "C" and _is_chiral(a):
						var nbs = []
						for nb_id in a.neighbors:
							var nb = _find(nb_id)
							if nb: nbs.append({"id": nb.id, "pri": Global._nb_pri(nb, a.id)})
						nbs.sort_custom(func(x, y): return x.pri < y.pri)
						if nbs.size() == 4:
							var other_id = bond.id2 if bond.id1 == a.id else bond.id1
							if other_id == nbs[0].id or other_id == nbs[3].id:
								vis = false
			if is_instance_valid(bond.get("line_ref")):
				bond.line_ref.visible = vis
			if is_instance_valid(bond.get("line_ref2")):
				bond.line_ref2.visible = vis
	else:
		for a in Global.atoms:
			if not is_instance_valid(a): continue
			a.draw_skeletal = false
			a.visible = true
			var col = a.get_node_or_null("CollisionShape2D")
			if col: col.disabled = false
			a.queue_redraw()
		_refresh_h_visibility()
	queue_redraw()


func is_2d_mode() -> bool:
	return view_mode == ViewMode.VIEW_2D


func _is_chiral(atom) -> bool:
	return Global.is_truly_chiral(atom)


# ---- 内部解链 ----
func _unlink_internal():
	var to_remove = []
	for bond in Global.bonds:
		var a_in = false
		for a in selected_atoms:
			if is_instance_valid(a) and (bond.id1 == a.id or bond.id2 == a.id):
				a_in = true
				break
		if a_in:
			var a1 = _find(bond.id1)
			var a2 = _find(bond.id2)
			if a1 and a2:
				a1.valence_used -= bond.bond_type
				a2.valence_used -= bond.bond_type
				a1.neighbors.erase(a2.id)
				a2.neighbors.erase(a1.id)
				a1.queue_redraw()
				a2.queue_redraw()
			if is_instance_valid(bond.get("line_ref")):
				bond.line_ref.queue_free()
			if is_instance_valid(bond.get("line_ref2")):
				bond.line_ref2.queue_free()
			if is_instance_valid(bond.get("line_ref3")):
				bond.line_ref3.queue_free()
			to_remove.append(bond)

	for b in to_remove:
		Global.bonds.erase(b)


func _try_bond(a: Area2D, b: Area2D):
	print("[CK] _try_bond: ", a.symbol, a.id, " - ", b.symbol, b.id)
	if b.id in a.neighbors:
		for bond in Global.bonds:
			if (bond.id1 == a.id and bond.id2 == b.id) or (bond.id1 == b.id and bond.id2 == a.id):
				if bond.bond_type >= 2:
					show_error.emit("重复成键", a.symbol + "-" + b.symbol + " 已是双键。")
					return
				bond.bond_type = 2
				a.valence_used += 1
				b.valence_used += 1
				var off = _perp(a.position, b.position)
				var l2 = _make_line()
				l2.points = [a.position + off, b.position + off]
				add_child(l2)
				bond.line_ref2 = l2
				a.queue_redraw(); b.queue_redraw()
				atom_changed.emit()
				return
		return

	if a.valence_used + 1 > a.valence_max:
		show_error.emit("价键超限", a.symbol + " 已达最大价键数 " + str(a.valence_max) + "！")
		return
	if b.valence_used + 1 > b.valence_max:
		show_error.emit("价键超限", b.symbol + " 已达最大价键数 " + str(b.valence_max) + "！")
		return

	_create_bond(a, b, 1)
	_relax_structure()
	_refresh_h_visibility()
	atom_changed.emit()


func _create_bond(a: Area2D, b: Area2D, btype: int, do_auto_pos: bool = true):
	if b.id in a.neighbors:
		for bond in Global.bonds:
			if (bond.id1 == a.id and bond.id2 == b.id) or (bond.id1 == b.id and bond.id2 == a.id):
				var diff = btype - bond.bond_type
				a.valence_used += diff; b.valence_used += diff
				bond.bond_type = btype
				if btype >= 2 and not is_instance_valid(bond.get("line_ref2")):
					var off = _perp(a.position, b.position)
					var l2 = _make_line(); l2.points = [a.position+off, b.position+off]
					add_child(l2); bond.line_ref2 = l2
				a.queue_redraw(); b.queue_redraw()
				return
		return

	a.valence_used += btype; b.valence_used += btype
	a.neighbors.append(b.id); b.neighbors.append(a.id)
	if do_auto_pos:
		_auto_pos(b, a)

	var line = _make_line(); line.points = [a.position, b.position]
	add_child(line)
	var bd = {"id1":a.id, "id2":b.id, "bond_type":btype, "line_ref":line, "line_ref2":null, "line_ref3":null}
	if btype >= 2:
		var off = _perp(a.position, b.position)
		var l2 = _make_line(); l2.points = [a.position+off, b.position+off]
		add_child(l2); bd.line_ref2 = l2
	if btype >= 3:
		var off = _perp(a.position, b.position)
		var l3 = _make_line(); l3.points = [a.position-off, b.position-off]
		add_child(l3); bd.line_ref3 = l3
	Global.bonds.append(bd)

	var hide_line = false
	if a.symbol == "H" and not Global.show_h:
		for nb_id in a.neighbors:
			if _find(nb_id) and _find(nb_id).symbol == "C":
				hide_line = true; break
	if b.symbol == "H" and not Global.show_h:
		for nb_id in b.neighbors:
			if _find(nb_id) and _find(nb_id).symbol == "C":
				hide_line = true; break
	if hide_line:
		line.visible = false
		if is_instance_valid(bd.get("line_ref2")):
			bd.line_ref2.visible = false

	a.queue_redraw(); b.queue_redraw()


func _auto_pos(moved: Area2D, anchor: Area2D):
	if moved.neighbors.size() > 1: return
	var existing = []
	for nb_id in anchor.neighbors:
		if nb_id == moved.id: continue
		var nb = _find(nb_id)
		if nb: existing.append(nb)
	if existing.is_empty():
		moved.position = anchor.position + Vector2(BOND_LEN, 0); return
	var is_straight = moved.symbol == "O" or anchor.symbol == "O"
	if existing.size() == 1 and not is_straight:
		var dir = (anchor.position - existing[0].position).normalized()
		var t1 = dir.rotated(deg_to_rad(15))
		var t2 = dir.rotated(deg_to_rad(-15))
		var p1 = anchor.position + t1 * BOND_LEN
		var p2 = anchor.position + t2 * BOND_LEN
		var d1 = 999.0; var d2 = 999.0
		for a in Global.atoms:
			if not is_instance_valid(a) or a == moved or a == anchor: continue
			d1 = min(d1, p1.distance_to(a.position))
			d2 = min(d2, p2.distance_to(a.position))
		moved.position = p1 if d1 >= d2 else p2
		return
	var angles = []
	for nb in existing:
		angles.append((nb.position - anchor.position).angle())
	angles.sort()
	var best_ang = 0.0; var best_gap = 0.0
	for i in range(angles.size()):
		var j = wrap(i+1, 0, angles.size())
		var gap = angles[j] - angles[i]
		if j == 0: gap += TAU
		if gap > best_gap: best_gap = gap; best_ang = angles[i] + gap/2.0
	moved.position = anchor.position + Vector2(cos(best_ang), sin(best_ang)) * BOND_LEN


func _make_line() -> Line2D:
	var l = Line2D.new()
	l.width = 5.0; l.default_color = Color(0.18, 0.18, 0.18)
	l.antialiased = true
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND; l.end_cap_mode = Line2D.LINE_CAP_ROUND
	return l


func _perp(p1: Vector2, p2: Vector2) -> Vector2:
	var d = p2 - p1
	if d.length() < 0.001: return Vector2(8,0)
	return Vector2(-d.y, d.x).normalized() * 7.0


# ============================================================
# 基团拼接
# ============================================================

func attach_group(gname: String, target: Area2D = null):
	if target == null and selected_atoms.size() == 1:
		target = selected_atoms[0]
	if target == null or not is_instance_valid(target):
		show_error.emit("未选择原子", "请先选中一个目标原子。")
		return
	if target.valence_used >= target.valence_max:
		show_error.emit("价键已满", target.symbol + " 无可用价键。")
		return

	match gname:
		"BtnOH":   _build_oh(target)
		"BtnNH2":  _build_nh2(target)
		"BtnCH3":  _build_ch3(target)
		"BtnCOOH": _build_cooh(target)
		"BtnCHO":  _build_cho(target)
		"BtnCO":   _build_co(target)
		"BtnNO2":  _build_no2(target)
		"BtnBenzene": _build_benzene(target)
	atom_changed.emit()


func _build_oh(t: Area2D):
	var o = _spawn("O", t.position + Vector2(BOND_LEN,0)); _create_bond(t,o,1)
	var h = _spawn("H", o.position + Vector2(0,-BOND_LEN)); _create_bond(o,h,1)
	_auto_pos(o,t)
	_refresh_h_visibility()

func _build_nh2(t: Area2D):
	var n = _spawn("N", t.position + Vector2(BOND_LEN,0)); _create_bond(t,n,1)
	var h1 = _spawn("H", n.position + Vector2(-40,-50)); _create_bond(n,h1,1)
	var h2 = _spawn("H", n.position + Vector2(40,-50)); _create_bond(n,h2,1)
	_auto_pos(n,t)
	_refresh_h_visibility()

func _build_ch3(t: Area2D):
	var c = _spawn("C", t.position + Vector2(BOND_LEN,0)); _create_bond(t,c,1)
	for ang in [0.0,120.0,240.0]:
		var r = deg_to_rad(ang-90)
		var h = _spawn("H", c.position + Vector2(cos(r), sin(r))*50); _create_bond(c,h,1)
	_auto_pos(c,t)
	_refresh_h_visibility()

func _build_cooh(t: Area2D):
	var c = _spawn("C", t.position + Vector2(BOND_LEN,0)); _create_bond(t,c,1)
	var o1 = _spawn("O", c.position + Vector2(0,-BOND_LEN)); _create_bond(c,o1,2)
	var o2 = _spawn("O", c.position + Vector2(40,50)); _create_bond(c,o2,1)
	var h  = _spawn("H", o2.position + Vector2(50,0)); _create_bond(o2,h,1)
	_auto_pos(c,t)
	_refresh_h_visibility()

func _build_cho(t: Area2D):
	var c = _spawn("C", t.position + Vector2(BOND_LEN,0)); _create_bond(t,c,1,false)
	var o = _spawn("O", c.position + Vector2(0,-BOND_LEN)); _create_bond(c,o,2,false)
	var h = _spawn("H", c.position + Vector2(0,BOND_LEN)); _create_bond(c,h,1,false)
	_auto_pos(c,t)
	_relax_structure()
	_refresh_h_visibility()

func _build_co(t: Area2D):
	var c = _spawn("C", t.position + Vector2(BOND_LEN,0)); _create_bond(t,c,1,false)
	var o = _spawn("O", c.position + Vector2(0,-BOND_LEN)); _create_bond(c,o,2,false)
	_auto_pos(c,t)
	_relax_structure()
	_refresh_h_visibility()

func _build_no2(t: Area2D):
	var n = _spawn("N", t.position + Vector2(BOND_LEN,0)); _create_bond(t,n,1,false)
	var o1 = _spawn("O", n.position + Vector2(-40,-50)); _create_bond(n,o1,1,false)
	var o2 = _spawn("O", n.position + Vector2(40,-50)); _create_bond(n,o2,1,false)
	_auto_pos(n,t)
	_relax_structure()
	_refresh_h_visibility()

func _build_benzene(t: Area2D):
	var out_dir = t.position + Vector2(BOND_LEN + RING_R, 0)
	var angles = []
	for nb_id in t.neighbors:
		var nb = _find(nb_id)
		if nb: angles.append((nb.position - t.position).angle())
	if not angles.is_empty():
		angles.sort()
		var best_gap = 0.0; var best_ang = 0.0
		for i in range(angles.size()):
			var j = wrap(i+1, 0, angles.size())
			var gap = angles[j] - angles[i]
			if j == 0: gap += TAU
			if gap > best_gap: best_gap = gap; best_ang = angles[i] + gap/2.0
		out_dir = t.position + Vector2(cos(best_ang), sin(best_ang)) * (BOND_LEN + RING_R)
	var ring = []
	for i in range(6):
		var ang = TAU * float(i) / 6.0 - PI/2.0
		var a = _spawn("C", out_dir + Vector2(cos(ang), sin(ang)) * RING_R)
		ring.append(a)
	for i in range(6):
		var j = wrap(i+1, 0, 6)
		var bt = 2 if i%2==0 else 1
		_create_bond(ring[i], ring[j], bt, false)
	_create_bond(t, ring[0], 1, false)
	for i in range(1, 6):
		var ang = TAU * float(i) / 6.0 - PI/2.0
		var h = _spawn("H", ring[i].position + Vector2(cos(ang), sin(ang)) * 60)
		_create_bond(ring[i], h, 1, false)
	_relax_structure()
	_refresh_h_visibility()
func spawn_fragment(name: String):
	var pos = Vector2(200, 360) + Vector2((spawn_index%8)*80, int(spawn_index/8)*80)
	spawn_index += 1
	match name:
		"BtnEster": _build_ester_fragment(pos)
		"BtnAmide": _build_amide_fragment(pos)
	_refresh_h_visibility()
	atom_changed.emit()


func _build_ester_fragment(pos: Vector2):
	var c = _spawn("C", pos)
	var o_dbl = _spawn("O", pos + Vector2(0, -BOND_LEN))
	var o_s = _spawn("O", pos + Vector2(BOND_LEN, 0))
	_create_bond(c, o_dbl, 2, false)
	_create_bond(c, o_s, 1, false)

func _build_amide_fragment(pos: Vector2):
	var c = _spawn("C", pos)
	var o = _spawn("O", pos + Vector2(0, -BOND_LEN))
	var n = _spawn("N", pos + Vector2(BOND_LEN, 0))
	var h = _spawn("H", n.position + Vector2(0, BOND_LEN))
	_create_bond(c, o, 2, false)
	_create_bond(c, n, 1, false)
	_create_bond(n, h, 1, false)






func _gen_ring(n: int, r: float, center: Vector2, syms: Array, btypes: Array, has_h: Array):
	var ring = []
	for i in range(n):
		var ang = TAU * float(i) / float(n) - PI/2.0
		var a = _spawn(syms[i], center + Vector2(cos(ang), sin(ang)) * r)
		ring.append(a)
	for i in range(n):
		var j = wrap(i+1, 0, n)
		_create_bond(ring[i], ring[j], btypes[i], false)
	for i in range(n):
		if not has_h[i]: continue
		var ang = TAU * float(i) / float(n) - PI/2.0
		var h = _spawn("H", ring[i].position + Vector2(cos(ang), sin(ang)) * 60)
		_create_bond(ring[i], h, 1, false)
	_relax_structure()
	_refresh_h_visibility()


# ============================================================
# 拖拽结束
# ============================================================

func _finish_drag():
	if not is_instance_valid(_pressed_atom): return
	for a in (selected_atoms if _pressed_atom in selected_atoms else [_pressed_atom]):
		if not is_instance_valid(a): continue
		a.modulate = Color.WHITE
		# 防重叠
		for _i in range(10):
			var ok = true
			for o in Global.atoms:
				if o == a or not is_instance_valid(o): continue
				if a.position.distance_to(o.position) < 40:
					a.position.x += 40; ok = false; break
			if ok: break
		a.queue_redraw()
	_drag_bases.clear()
	# 恢复多选绿色高亮
	for a in selected_atoms:
		if is_instance_valid(a):
			a.modulate = Color(0.5, 1.0, 0.5)
	_refresh_h_visibility()
	atom_changed.emit()


# ============================================================
# 删除
# ============================================================

func _delete_atom(atom: Area2D):
	print("[CK] _delete_atom: ", atom.symbol, atom.id)
	var h_to_delete = []
	if Global.auto_clean_H and atom.symbol in ["C", "O", "N"]:
		for nb_id in atom.neighbors:
			var nb = _find(nb_id)
			if nb and nb.symbol == "H":
				h_to_delete.append(nb)

	for bond in Global.bonds.duplicate():
		if bond.id1 == atom.id or bond.id2 == atom.id:
			if is_instance_valid(bond.get("line_ref")): bond.line_ref.queue_free()
			if is_instance_valid(bond.get("line_ref2")): bond.line_ref2.queue_free()
			if is_instance_valid(bond.get("line_ref3")): bond.line_ref3.queue_free()
			var oid = bond.id2 if bond.id1 == atom.id else bond.id1
			var o = _find(oid)
			if o:
				o.valence_used -= bond.get("bond_type", 1)
				o.neighbors.erase(atom.id); o.queue_redraw()
			Global.bonds.erase(bond)
	Global.atoms.erase(atom)
	atom.queue_free()

	for h in h_to_delete:
		if is_instance_valid(h):
			_delete_atom(h)


# ============================================================
# 放置
# ============================================================

func place_atom(sym: String):
	print("[CK] place_atom: ", sym)
	var a: Area2D = ATOM_SCENE.instantiate()
	a.setup(sym, Global.get_next_id())
	a.z_index = 2 if sym not in ["C", "H"] else 1
	a.position = Vector2(100,360) + Vector2((spawn_index%8)*60, int(spawn_index/8)*60)
	spawn_index += 1
	add_child(a); Global.atoms.append(a)
	_refresh_h_visibility()
	atom_changed.emit()


func _spawn(sym: String, pos: Vector2) -> Area2D:
	var a: Area2D = ATOM_SCENE.instantiate()
	a.setup(sym, Global.get_next_id())
	a.position = pos
	a.z_index = 2 if sym not in ["C", "H"] else 1
	add_child(a); Global.atoms.append(a)
	return a

func _refresh_h_visibility():
	for a in Global.atoms:
		if not is_instance_valid(a) or a.symbol != "H":
			continue
		var show = true
		if not Global.show_h:
			for nb_id in a.neighbors:
				var nb = _find(nb_id)
				if nb and nb.symbol == "C":
					show = false
					break
		a.visible = show
		var col = a.get_node_or_null("CollisionShape2D")
		if col: col.disabled = !show

	for bond in Global.bonds:
		var a1 = _find(bond.id1); var a2 = _find(bond.id2)
		if not a1 or not a2: continue
		var h_hidden = a1.symbol == "H" and not a1.visible
		if a2.symbol == "H" and not a2.visible: h_hidden = true
		if is_instance_valid(bond.get("line_ref")):
			bond.line_ref.visible = not h_hidden
		if is_instance_valid(bond.get("line_ref2")):
			bond.line_ref2.visible = not h_hidden


func update_h_bond_visibility(_visible: bool):
	_refresh_h_visibility()


# ============================================================
# 工具
# ============================================================

func _hit(pos: Vector2) -> Area2D:
	var q = PhysicsPointQueryParameters2D.new()
	q.position = pos; q.collide_with_areas = true; q.collide_with_bodies = false
	for r in get_world_2d().direct_space_state.intersect_point(q):
		var c = r.collider
		if c is Area2D and c.has_method("setup"): return c
	return null

func _find(id: int):
	for a in Global.atoms:
		if is_instance_valid(a) and a.id == id: return a
	return null


# ============================================================
# 结构弛豫：统一键长 + 分散角度
# ============================================================

func _relax_structure():
	return


func get_selected() -> Area2D:
	if selected_atoms.size() > 0:
		return selected_atoms[0]
	return null

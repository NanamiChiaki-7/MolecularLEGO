extends Control
# 作者:CK

# ============================================================
# Main.gd — 程序化 UI 构建 + M1 成键逻辑中枢
# ============================================================

var canvas_world: Node2D
var info_label: RichTextLabel
var analysis_label: RichTextLabel
var settings_popup: PopupPanel
var custom_input: LineEdit
var left_vbox: VBoxContainer
var group_buttons: Dictionary = {}
var _sv2d: SubViewport
var _sv3d: SubViewport


func _ready():
	_apply_theme()
	build_ui()
	update_info()


func _apply_theme():
	var t = Theme.new()
	var bg    = Color(0.102, 0.114, 0.137)
	var panel = Color(0.145, 0.157, 0.188)
	var surf  = Color(0.180, 0.192, 0.220)
	var acc   = Color(0.290, 0.620, 1.0)
	var txt   = Color(0.878, 0.894, 0.910)
	var bor   = Color(0.188, 0.212, 0.239)

	t.set_default_font(ThemeDB.fallback_font)
	t.set_color("font_color", "Label", txt)
	t.set_color("font_color", "Button", txt)
	t.set_color("font_color", "CheckBox", txt)
	t.set_color("font_color", "RichTextLabel", txt)
	t.set_color("font_color", "LineEdit", txt)
	t.set_font_size("font_size", "Label", 13)
	t.set_font_size("font_size", "Button", 13)

	var ps = StyleBoxFlat.new(); ps.bg_color=panel
	ps.corner_radius_top_left=6; ps.corner_radius_top_right=6
	ps.corner_radius_bottom_left=6; ps.corner_radius_bottom_right=6
	t.set_stylebox("panel", "Panel", ps)

	var bs = StyleBoxFlat.new(); bs.bg_color=surf
	bs.corner_radius_top_left=4; bs.corner_radius_top_right=4
	bs.corner_radius_bottom_left=4; bs.corner_radius_bottom_right=4
	bs.border_width_left=1; bs.border_width_right=1
	bs.border_width_top=1; bs.border_width_bottom=1; bs.border_color=bor
	t.set_stylebox("normal", "Button", bs)

	var bh = StyleBoxFlat.new(); bh.bg_color=acc.darkened(0.15)
	bh.corner_radius_top_left=4; bh.corner_radius_top_right=4
	bh.corner_radius_bottom_left=4; bh.corner_radius_bottom_right=4
	bh.border_width_left=1; bh.border_width_right=1
	bh.border_width_top=1; bh.border_width_bottom=1; bh.border_color=acc
	t.set_stylebox("hover", "Button", bh)

	var bp = StyleBoxFlat.new(); bp.bg_color=acc.darkened(0.3)
	bp.corner_radius_top_left=4; bp.corner_radius_top_right=4
	bp.corner_radius_bottom_left=4; bp.corner_radius_bottom_right=4
	bp.border_width_left=1; bp.border_width_right=1
	bp.border_width_top=1; bp.border_width_bottom=1; bp.border_color=acc
	t.set_stylebox("pressed", "Button", bp)

	var ls = StyleBoxFlat.new(); ls.bg_color=Color(0.118,0.133,0.157)
	ls.corner_radius_top_left=4; ls.corner_radius_top_right=4
	ls.corner_radius_bottom_left=4; ls.corner_radius_bottom_right=4
	ls.border_width_left=1; ls.border_width_right=1
	ls.border_width_top=1; ls.border_width_bottom=1; ls.border_color=bor
	t.set_stylebox("normal", "LineEdit", ls)

	var lf = StyleBoxFlat.new(); lf.bg_color=Color(0.118,0.133,0.157)
	lf.corner_radius_top_left=4; lf.corner_radius_top_right=4
	lf.corner_radius_bottom_left=4; lf.corner_radius_bottom_right=4
	lf.border_width_left=1; lf.border_width_right=1
	lf.border_width_top=1; lf.border_width_bottom=1; lf.border_color=acc
	t.set_stylebox("focus", "LineEdit", lf)

	var pps = StyleBoxFlat.new(); pps.bg_color=panel
	pps.corner_radius_top_left=8; pps.corner_radius_top_right=8
	pps.corner_radius_bottom_left=8; pps.corner_radius_bottom_right=8
	pps.border_width_left=1; pps.border_width_right=1
	pps.border_width_top=1; pps.border_width_bottom=1; pps.border_color=bor
	t.set_stylebox("panel", "PopupPanel", pps)

	var scs = StyleBoxFlat.new(); scs.bg_color=Color(0,0,0,0)
	t.set_stylebox("panel", "ScrollContainer", scs)

	var hs = StyleBoxFlat.new(); hs.bg_color=bor
	t.set_stylebox("separator", "HSeparator", hs)

	t.set_color("default_color", "RichTextLabel", txt)

	var ads = StyleBoxFlat.new(); ads.bg_color=panel
	ads.corner_radius_top_left=8; ads.corner_radius_top_right=8
	ads.corner_radius_bottom_left=8; ads.corner_radius_bottom_right=8
	ads.border_width_left=1; ads.border_width_right=1
	ads.border_width_top=1; ads.border_width_bottom=1; ads.border_color=bor
	t.set_stylebox("panel", "AcceptDialog", ads)

	self.theme = t


# ============================================================
# UI 构建
# ============================================================

func build_ui():
	# 根布局 HBoxContainer 填满屏幕
	var layout = HBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_preset(PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)

	_build_left(layout)
	_build_canvas(layout)
	_build_right(layout)
	_build_settings()


func _build_left(parent: HBoxContainer):
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(155, 0)
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(panel)

	# 外层 margin
	var outer_margin = MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 8)
	outer_margin.add_theme_constant_override("margin_top", 8)
	outer_margin.add_theme_constant_override("margin_right", 8)
	outer_margin.add_theme_constant_override("margin_bottom", 8)
	outer_margin.set_anchors_preset(PRESET_FULL_RECT)
	panel.add_child(outer_margin)

	# 滚动区域
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	outer_margin.add_child(scroll)

	# 内容 VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# 标题
	var t = Label.new()
	t.text = "元素工具栏"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 16)
	vbox.add_child(t)
	vbox.add_child(HSeparator.new())

	# 四个核心原子按钮
	_add_btn(vbox, "BtnC", "C  碳  (4价)", Color(0.25, 0.25, 0.25), _on_atom.bind("C"))
	_add_btn(vbox, "BtnH", "H  氢  (1价)", Color(0.90, 0.90, 0.90), _on_atom.bind("H"))
	_add_btn(vbox, "BtnO", "O  氧  (2价)", Color(0.90, 0.20, 0.20), _on_atom.bind("O"))
	_add_btn(vbox, "BtnN", "N  氮  (3价)", Color(0.20, 0.30, 0.90), _on_atom.bind("N"))

	vbox.add_child(HSeparator.new())

	# 自定义原子行
	var cl = Label.new()
	cl.text = "自定义原子"
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cl)

	var row = HBoxContainer.new()
	row.name = "CustomRow"
	custom_input = LineEdit.new()
	custom_input.name = "CustomInput"
	custom_input.placeholder_text = "元素符号 (如K)"
	custom_input.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(custom_input)

	var cbtn = Button.new()
	cbtn.text = "生成"
	cbtn.pressed.connect(_on_custom_atom)
	row.add_child(cbtn)
	vbox.add_child(row)

	vbox.add_child(HSeparator.new())

	# 基团/键
	var gl = Label.new()
	gl.text = "基团/键"
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(gl)

	for data in [
		["BtnOH",   "-OH  羟基"],
		["BtnCH3",  "-CH₃ 甲基"],
		["BtnCHO",  "-CHO 醛基"],
		["BtnCO",   ">C=O 羰基"],
		["BtnCOOH", "-COOH 羧基"],
		["BtnNH2",  "-NH₂ 氨基"],
		["BtnNO2",  "-NO₂ 硝基"],
		["BtnBenzene", "苯基 -C₆H₅"],
	]:
		var b = _add_btn(vbox, data[0], data[1], Color(0.35, 0.35, 0.35), _on_group.bind(data[0]))
		if b:
			group_buttons[data[0]] = b

	var frags = [
		["BtnEster", "酯键 -COO-"],
		["BtnAmide", "肽键 -CONH-"],
	]
	for fd in frags:
		_add_btn(vbox, fd[0], fd[1], Color(0.30, 0.35, 0.40), _on_fragment.bind(fd[0]))

	vbox.add_child(HSeparator.new())

	# 清空
	var cb = Button.new()
	cb.text = "清空画布"
	cb.pressed.connect(_on_clear)
	vbox.add_child(cb)


func _build_canvas(parent: HBoxContainer):
	var svc = SubViewportContainer.new()
	svc.name = "CanvasContainer"
	svc.size_flags_horizontal = SIZE_EXPAND_FILL
	svc.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(svc)

	# --- 2D 画布 ---
	var sv2d = SubViewport.new()
	sv2d.name = "SubViewport2D"
	sv2d.size = Vector2i(885, 720)
	sv2d.transparent_bg = false
	svc.add_child(sv2d)
	_sv2d = sv2d

	var cw = Node2D.new()
	cw.name = "CanvasWorld"
	cw.set_script(load("res://scripts/CanvasWorld.gd"))
	sv2d.add_child(cw)
	canvas_world = cw
	cw.atom_changed.connect(update_info)
	cw.show_error.connect(_alert_popup)
	cw.request_context_menu.connect(_show_ctx_menu)

	# --- 3D 视口（默认隐藏） ---
	var sv3d = SubViewport.new()
	sv3d.name = "SubViewport3D"
	sv3d.size = Vector2i(885, 720)
	sv3d.transparent_bg = false
	_sv3d = sv3d

	var mv = Node3D.new(); mv.name = "Mol3DView"
	mv.set_script(load("res://scripts/Mol3DView.gd"))
	sv3d.add_child(mv)

	# 视图切换按钮组（画布右上角）
	var vp = Panel.new()
	vp.name = "ViewPanel"
	var vps = StyleBoxFlat.new()
	vps.bg_color = Color(0.06, 0.06, 0.09, 0.85)
	vps.corner_radius_top_left = 6; vps.corner_radius_top_right = 6
	vps.corner_radius_bottom_left = 6; vps.corner_radius_bottom_right = 6
	vp.add_theme_stylebox_override("panel", vps)
	svc.add_child(vp)

	var vhb = HBoxContainer.new()
	vhb.add_theme_constant_override("separation", 2)
	vp.add_child(vhb)

	var v2d = Button.new(); v2d.text = "2D"; v2d.flat = true
	v2d.add_theme_font_size_override("font_size", 20)
	v2d.custom_minimum_size = Vector2(28, 20)
	vhb.add_child(v2d)

	var v3d = Button.new(); v3d.text = "3D"; v3d.flat = true
	v3d.add_theme_font_size_override("font_size", 20)
	v3d.custom_minimum_size = Vector2(48, 20)
	vhb.add_child(v3d)

	var vsk = Button.new(); vsk.text = "键线"; vsk.flat = true
	vsk.add_theme_font_size_override("font_size", 20)
	vsk.custom_minimum_size = Vector2(58, 20)
	vhb.add_child(vsk)


	_set_view_btn_active(v3d, false)
	_set_view_btn_active(vsk, false)
	_set_view_btn_active(v2d, true)
	v2d.pressed.connect(func(): _on_view_btn("2d", v2d, v3d, vsk))
	v3d.pressed.connect(func(): _on_view_btn("3d", v2d, v3d, vsk))
	vsk.pressed.connect(func(): _on_view_btn("skeletal", v2d, v3d, vsk))


func _on_view_btn(mode: String, v2d: Button, v3d: Button, vsk: Button):
	_set_view_btn_active(v2d, mode == "2d")
	_set_view_btn_active(v3d, mode == "3d")
	_set_view_btn_active(vsk, mode == "skeletal")
	_switch_to_view(mode)


func _set_view_btn_active(btn: Button, active: bool):
	if active:
		btn.add_theme_color_override("font_color", Color.WHITE)
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.29, 0.62, 1.0, 0.45)
		s.corner_radius_top_left = 3; s.corner_radius_top_right = 3
		s.corner_radius_bottom_left = 3; s.corner_radius_bottom_right = 3
		btn.add_theme_stylebox_override("normal", s)
	else:
		btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0, 0, 0, 0)
		btn.add_theme_stylebox_override("normal", s)


func _switch_to_view(mode: String):
	var svc = $Layout/CanvasContainer
	if mode == "2d":
		if _sv3d.get_parent(): svc.remove_child(_sv3d)
		svc.add_child(_sv2d)
		if canvas_world and canvas_world.has_method("set_view_mode"):
			canvas_world.set_view_mode(0)
	elif mode == "3d":
		if _sv2d.get_parent(): svc.remove_child(_sv2d)
		svc.add_child(_sv3d)
		var mv = _sv3d.get_node_or_null("Mol3DView")
		if mv and mv.has_method("mark_dirty"): mv.mark_dirty()
	else:
		if _sv3d.get_parent(): svc.remove_child(_sv3d)
		svc.add_child(_sv2d)
		if canvas_world and canvas_world.has_method("set_view_mode"):
			canvas_world.set_view_mode(2)
	update_info()


func _build_right(parent: HBoxContainer):
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(240, 0)
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(panel)

	var vbox = _vbox_in_margin(panel, 8, 4)

	# 标题行 + 3D 切换按钮
	var title_row = HBoxContainer.new()
	var t = Label.new()
	t.text = "分子信息"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.add_theme_font_size_override("font_size", 16)
	title_row.add_child(t)
	vbox.add_child(title_row)
	vbox.add_child(HSeparator.new())

	info_label = RichTextLabel.new()
	info_label.name = "InfoLabel"
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.scroll_active = false
	info_label.text = "[i]点击左侧按钮添加原子...[/i]"
	vbox.add_child(info_label)
	vbox.add_child(HSeparator.new())

	var at = Label.new()
	at.text = "结构分析"
	at.add_theme_font_size_override("font_size", 14)
	vbox.add_child(at)

	analysis_label = RichTextLabel.new()
	analysis_label.name = "AnalysisLabel"
	analysis_label.bbcode_enabled = true
	analysis_label.fit_content = true
	analysis_label.scroll_active = false
	vbox.add_child(analysis_label)

	# 水印
	var wm = Label.new()
	wm.text = "本模拟基于价键理论简化模型\n仅供科普教学参考"
	wm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wm.add_theme_font_size_override("font_size", 9)
	wm.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(wm)

	var sp = Control.new()
	sp.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(sp)

	var sb = Button.new()
	sb.text = "⚙ 设置"
	sb.pressed.connect(func(): if settings_popup: settings_popup.popup_centered())
	vbox.add_child(sb)

	var kb = Button.new()
	kb.text = "📖 科普"
	kb.pressed.connect(_show_kepu)
	vbox.add_child(kb)


func _build_settings():
	settings_popup = PopupPanel.new()
	settings_popup.name = "SettingsPopup"
	settings_popup.title = "设置"
	settings_popup.size = Vector2i(300, 270)
	add_child(settings_popup)

	var vbox = _vbox_in_margin(settings_popup, 15, 12)

	var cb1 = CheckBox.new()
	cb1.text = "显示非基团 H 原子"
	cb1.toggled.connect(_on_show_h)
	vbox.add_child(cb1)

	var cb2 = CheckBox.new()
	cb2.text = "显示手性标记 (*)"
	cb2.toggled.connect(_on_show_chiral)
	vbox.add_child(cb2)

	var cb3 = CheckBox.new()
	cb3.text = "禁用稳定性限制"
	cb3.toggled.connect(_on_stability)
	vbox.add_child(cb3)

	var cb4 = CheckBox.new()
	cb4.button_pressed = true
	cb4.text = "删除时自动清理相连 H"
	cb4.toggled.connect(_on_auto_clean_h)
	vbox.add_child(cb4)

	var disc = Label.new()
	disc.text = "本模拟基于价键理论简化模型\n仅供科普教学参考"
	disc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disc.add_theme_font_size_override("font_size", 9)
	disc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(disc)


# ============================================================
# 辅助
# ============================================================

func _vbox_in_margin(parent: Node, padding: int, sep: int) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", sep)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", padding)
	margin.add_theme_constant_override("margin_top", padding)
	margin.add_theme_constant_override("margin_right", padding)
	margin.add_theme_constant_override("margin_bottom", padding)
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_child(vbox)
	parent.add_child(margin)       # ← 修复：margin 挂到 parent
	return vbox                     # vbox 始终在 margin 内


func _add_btn(parent: VBoxContainer, _name: String, text: String, col: Color, cb: Callable) -> Button:
	var btn = Button.new()
	btn.name = _name
	btn.text = text
	btn.pressed.connect(cb)

	var s = StyleBoxFlat.new()
	s.bg_color = col
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_color_override("font_color",
		Color.WHITE if col.v < 0.5 else Color.BLACK)
	parent.add_child(btn)
	return btn


# ============================================================
# 原子 / 自定义 / 清空
# ============================================================

func _guard_2d()->bool:
	if canvas_world and canvas_world.has_method("is_2d_mode") and not canvas_world.is_2d_mode():
		_alert("视图限制", "请在2D视图下进行操作。")
		return false
	return true


func _on_atom(sym: String):
	if not _guard_2d(): return
	if canvas_world and canvas_world.has_method("place_atom"):
		canvas_world.place_atom(sym)


func _on_custom_atom():
	if not _guard_2d(): return
	if not custom_input:
		return
	var raw = custom_input.text.strip_edges()
	if raw.is_empty():
		return
	var sym = raw[0].to_upper() + raw.substr(1).to_lower()
	if sym.length() > 2:
		_alert("输入错误", "元素符号最多2字符")
		return
	if not Global.atom_colors.has(sym):
		Global.atom_colors[sym]  = Color(0.6, 0.2, 0.8)
		Global.atom_valence[sym] = 1
		Global.atom_weight[sym]  = 39
	if canvas_world and canvas_world.has_method("place_atom"):
		canvas_world.place_atom(sym)
	custom_input.text = ""


func _on_clear():
	for a in Global.atoms.duplicate():
		if is_instance_valid(a):
			a.queue_free()
	for b in Global.bonds:
		if is_instance_valid(b.get("line_ref")):
			b.line_ref.queue_free()
		if is_instance_valid(b.get("line_ref2")):
			b.line_ref2.queue_free()
		if is_instance_valid(b.get("line_ref3")):
			b.line_ref3.queue_free()
	Global.atoms.clear()
	Global.bonds.clear()
	if canvas_world:
		canvas_world.clear_selection()
	update_info()


func _on_group(gname: String):
	if not _guard_2d(): return
	if canvas_world and canvas_world.has_method("attach_group"):
		var target = null
		if canvas_world.has_method("get_selected"):
			target = canvas_world.get_selected()
		canvas_world.attach_group(gname, target)


func _on_fragment(fname: String):
	if not _guard_2d(): return
	if canvas_world and canvas_world.has_method("spawn_fragment"):
		canvas_world.spawn_fragment(fname)


# ============================================================
# 设置
# ============================================================

func _on_show_h(pressed: bool):
	Global.show_h = pressed
	if canvas_world and canvas_world.has_method("update_h_bond_visibility"):
		canvas_world.update_h_bond_visibility(pressed)


func _on_show_chiral(pressed: bool):
	Global.show_chiral = pressed
	update_info()


func _on_stability(pressed: bool):
	Global.stability_enabled = !pressed
	update_info()


func _on_auto_clean_h(pressed: bool):
	Global.auto_clean_H = pressed


# ============================================================
# 信息面板
# ============================================================

func update_info():
	if info_label == null or analysis_label == null:
		return

	var r = Global.analyze()
	var txt = ""

	if r.formula != "":
		txt += "[b]结构式:[/b]  " + r.formula + "\n"
	if r.iupac != "":
		txt += "[b]IUPAC:[/b]  " + r.iupac + "\n"
	if r.matched and r.info != "":
		txt += r.info + "\n"
	else:
		var fp = Global.generate_fingerprint()
		txt += "\n[color=gray]指纹: " + fp + "[/color]\n"
		if Global.atoms.size() > 0:
			txt += "[i]暂无介绍[/i]\n"

	var na = Global.atoms.size()
	var nb = Global.bonds.size()
	var w  = 0
	for a in Global.atoms:
		if is_instance_valid(a):
			w += Global.get_weight(a.symbol)

	txt += "\n[b]统计:[/b]\n"
	txt += "原子: " + str(na) + "   化学键: " + str(nb) + "\n"
	txt += "分子量: ~" + str(w) + " g/mol\n"
	txt += "不饱和度 Ω: " + str(r.unsat) + "\n"
	info_label.text = txt

	if Global.stability_enabled and Global.check_unstable():
		var details = Global.get_unstable_details()
		var warn = "[color=red][b]⚠️ 检测到不稳定结构！[/b][/color]\n"
		if "peroxide" in details:
			warn += "[b]• 过氧键 (O-O)[/b]\n  过氧化物易分解爆炸，需避光低温保存。\n"
		if "cumulene" in details:
			warn += "[b]• 累积双键 (C=C=C)[/b]\n  高度不稳定，易重排或聚合。\n"
		if "azide" in details:
			warn += "[b]• 偶氮/叠氮 (N=N)[/b]\n  多氮多键连接，叠氮化合物易爆，偶氮化合物光敏。\n"
		analysis_label.text = warn
	else:
		analysis_label.text = "[color=green]✓ 结构稳定[/color]"


# ============================================================
# 右键菜单（在主 viewport 弹出，避免 SubViewport 坐标问题）
# ============================================================

func _show_ctx_menu():
	var menu = PopupMenu.new()
	menu.add_item("删除选中", 0)
	menu.add_item("断开所有链接", 1)
	menu.add_item("补齐饱和度", 3)
	menu.add_separator()
	menu.add_item("取消选中", 2)
	menu.id_pressed.connect(_on_ctx_action)
	add_child(menu)
	menu.popup_on_parent(Rect2i(get_global_mouse_position(), Vector2i.ZERO))


func _on_ctx_action(id: int):
	match id:
		0:
			if canvas_world and canvas_world.has_method("delete_selected"):
				canvas_world.delete_selected()
		1:
			if canvas_world and canvas_world.has_method("unlink_selected"):
				canvas_world.unlink_selected()
		2:
			if canvas_world and canvas_world.has_method("clear_selection"):
				canvas_world.clear_selection()
		3:
			if canvas_world and canvas_world.has_method("saturate_valence"):
				canvas_world.saturate_valence()


func _show_kepu():
	var popup = PopupPanel.new()
	popup.title = "化学基础知识科普"
	popup.size = Vector2i(720, 560)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(margin)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = KEPU_TEXT
	scroll.add_child(label)

	add_child(popup)
	popup.popup_centered()


const KEPU_TEXT = """[b][font_size=18]一、手性 (Chirality)[/font_size][/b]
[img=640x200]res://kepu/chirality_compare.png[/img]

[b]定义[/b]：一个碳原子连接 [b]四个不同的基团或原子[/b]，该碳称为 [color=purple]手性碳[/color]（Chiral Carbon），用 [b]*[/b] 标记。

[b]特征[/b]：
• 手性分子与其镜像不可重叠（像左右手）
• 互为镜像的两个分子称为 [b]对映异构体[/b]（Enantiomers）
• 对映体物理性质几乎相同，但 [b]旋光方向相反[/b]

[b]实例[/b]：
• 乳酸（CH₃-CH(OH)-COOH）：中心碳连接 H、OH、CH₃、COOH，四者各不相同 → 手性
• 氨基酸（除甘氨酸外）：α-碳连接 NH₂、COOH、H、R 基团 → 手性
• 葡萄糖有 4 个手性碳，果糖有 3 个
• 药物"沙利度胺"：R-构型有镇静作用，S-构型致畸 — 手性决定药效与毒性

[b]标记法[/b]：
• [b]R/S 标号[/b]（Cahn-Ingold-Prelog 规则）：按原子序数排优先顺序，最低优先基团在后，顺→R 逆→S
• [b]D/L 标号[/b]（Fischer 投影）：最高氧化态碳在上，主链垂直，取代基水平→向右为 D


[b][font_size=18]二、旋光性 (Optical Activity)[/font_size][/b]
[img=640x200]res://kepu/optical_activity.png[/img]

[b]原理[/b]：手性分子使平面偏振光的偏振面旋转。
• [b]右旋[/b]（dextrorotatory, + / d）：偏振面顺时针旋转
• [b]左旋[/b]（levorotatory, − / l）：偏振面逆时针旋转
• 外消旋体（racemate）：等量对映体的混合物 → 旋光性抵消

[b]实例[/b]：
• 天然葡萄糖为 D-(+)-葡萄糖（右旋）
• 天然果糖为 D-(−)-果糖（左旋，旋转角度更大）
• 同一 D/L 构型 ≠ 同一旋转方向（D/L 是构型标号，+/− 是实验值）
• 酒石酸有 3 种立体异构体：(+)酒石酸、(−)酒石酸、内消旋酒石酸

[b]应用[/b]：
• 旋光仪测糖浓度（制糖工业、糖尿病检测）
• 药物纯度分析（单一对映体 vs 外消旋）


[b][font_size=18]三、几何异构 (Geometric Isomerism)[/font_size][/b]
[img=640x200]res://kepu/geometric_isomer.png[/img]

[b]定义[/b]：由 [b]双键或环[/b] 阻碍旋转导致取代基空间排列不同产生的异构。

[b]类型[/b]：
• [b]顺反异构[/b]（cis/trans）：双键两侧相同基团在同侧→顺，异侧→反
• [b]E/Z 标号[/b]（CIP 扩展）：按优先规则，高优先基团同侧→Z（zusammen），异侧→E（entgegen）
• 环状化合物的顺反：取代基在环同侧→顺，异侧→反

[b]实例[/b]：
• 顺-1,2-二氯乙烯 vs 反-1,2-二氯乙烯：沸点不同（60°C vs 48°C）
• 顺丁烯二酸（马来酸）vs 反丁烯二酸（富马酸）：熔点差异巨大（130°C vs 287°C）
• 视黄醛（维生素A）：11-顺视黄醛在光照下变全反 → 触发视觉信号
• 偶氮苯：光控顺反异构实现分子开关

[b]为什么不能旋转？[/b]：双键的 π 键使旋转需 ~250 kJ/mol 能量，常温无法克服。


[b][font_size=18]四、不饱和度 (Degree of Unsaturation, Ω)[/font_size][/b]

[b]公式[/b]：Ω = (2C + 2 + N − H − X) / 2
其中 C=碳数，N=氮数，H=氢数，X=卤素数（F,Cl,Br,I）。O 和 S 不参与计算。

[b]含义[/b]：
• Ω=0：饱和烷烃（无环无双键）
• Ω=1：一个双键 [b]或[/b] 一个环
• Ω=2：两个双键 / 一个三键 / 双键+环 / 两个环
• Ω=4：苯环（三个双键 + 一个环）
• Ω=5：苯环 + 一个双键（如苯乙烯）

[b]实例[/b]：
• 乙烷 C₂H₆ → Ω=0（饱和）
• 乙烯 C₂H₄ → Ω=1（一个 C=C）
• 乙炔 C₂H₂ → Ω=2（一个 C≡C）
• 苯 C₆H₆ → Ω=4（环+3 双键）
• 吡啶 C₅H₅N → Ω=4（环+3 双键）
• 胆固醇 C₂₇H₄₆O → Ω=5（4 环+1 双键）


[b][font_size=18]五、互变异构 (Tautomerism)[/font_size][/b]

[b]定义[/b]：分子内质子迁移导致结构互变，两种异构体处于动态平衡。

[b]最常见：酮-烯醇互变异构[/b]
• 酮式：C=O（羰基），通常更稳定
• 烯醇式：C=C-OH，一般不稳定
• 例：丙酮中烯醇式仅占 ~0.0001%
• 例外：乙酰丙酮（CH₃COCH₂COCH₃）烯醇式因分子内氢键占 ~80%
• β-二酮/β-酮酯的烯醇式因共轭+氢键而稳定

[b]其他互变异构[/b]：
• 亚胺-烯胺互变（C=N ⇌ C=C-NH₂）
• 酰胺-亚胺酸互变
• 糖类的开链-环状互变（如葡萄糖在溶液中 ~99% 为环状吡喃糖）


[b][font_size=18]六、共振与芳香性[/font_size][/b]
[img=640x200]res://kepu/aromaticity.png[/img]

[b]共振 (Resonance)[/b]：单一 Lewis 结构式无法准确描述分子时，实际结构为多个极限式的 [b]共振杂化体[/b]。

[b]芳香性 (Aromaticity)[/b] — Hückel 规则：
1. 分子为平面环状
2. 环上每个原子有 p 轨道参与共轭
3. π 电子数 = 4n+2（n=0,1,2...）即 2,6,10,14...

[b]实例[/b]：
• 苯 C₆H₆：6π 电子 (4×1+2) → 芳香性 ✓
• 吡啶 C₅H₅N：6π 电子 → 芳香性 ✓（N 孤对在 sp² 轨道不参与）
• 吡咯 C₄H₅N：6π 电子 → 芳香性 ✓（N 孤对参与 π 体系）
• 呋喃 C₄H₄O：6π 电子 → 芳香性 ✓
• 咪唑 C₃H₄N₂：6π 电子 → 芳香性 ✓
• 环辛四烯 C₈H₈：8π 电子 (4×2) → 非芳香性 [b]且非平面[/b]
• 环丁二烯 C₄H₄：4π 电子 → 反芳香性（极度不稳定）


[b][font_size=18]七、诱导效应与共轭效应[/font_size][/b]

[b]诱导效应 (Inductive Effect)[/b]：通过 σ 键传递的电子效应。
• [b]吸电子基[/b]（−I）：NO₂ > CN > F > Cl > Br > OH > C₆H₅ > H
• [b]推电子基[/b]（+I）：烷基（CH₃, C₂H₅）> H

[b]共轭效应 (Conjugation)[/b]：通过 π 键传递的电子效应。
• [b]吸电子共轭[/b]（−C）：C=O, NO₂, CN（π 电子向取代基流动）
• [b]推电子共轭[/b]（+C）：NH₂, OH, OR, X（孤对电子向双键/环流动）

[b]实例[/b]：
• 苯酚的酸性（pKa≈10）强于环己醇（pKa≈16）：苯氧负离子共振稳定
• 苯甲酸的酸性（pKa≈4.2）强于乙酸（pKa≈4.8）：苯环 +C 效应
• 对硝基苯酚酸性（pKa≈7.2）强于苯酚：−NO₂ 的 −I/−C 效应叠加
• 苯胺碱性弱于环己胺：N 孤对参与芳环共轭

"""


# ============================================================
# 弹窗
# ============================================================

func _alert_popup(title: String, msg: String):
	_alert(title, msg)


func _alert(title: String, msg: String):
	var dlg = AcceptDialog.new()
	dlg.title = title
	dlg.dialog_text = msg
	add_child(dlg)
	dlg.popup_centered()

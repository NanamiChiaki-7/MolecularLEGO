extends Node3D
class_name Mol3DView
# 作者:CK

# ============================================================
# Mol3DView — 3D 分子渲染（几何结构生成）
# ============================================================

signal bond_hovered(bond_ids: Array, angle_deg: float)
signal bond_unhovered()

const BALL_R: float = 0.45
const STICK_R: float = 0.14
const BOND_LEN: float = 1.6

var _atoms: Dictionary = {}
var _bonds: Dictionary = {}
var _pos3d: Dictionary = {}      # id → Vector3

var _cam: Camera3D
var _cam_target: Vector3 = Vector3.ZERO
var _orbiting: bool = false
var _panning: bool = false
var _drag_start: Vector2
var _orbit_h: float = -30.0
var _orbit_v: float = 30.0
var _orbit_dist: float = 10.0
var _idle_timer: float = 0.0
var _dirty: bool = true

func mark_dirty():
	_dirty=true


func _ready():
	_cam = Camera3D.new(); _cam.name = "Camera3D"
	_cam.position = Vector3(0, 3, 6); _cam.look_at(Vector3.ZERO)
	add_child(_cam)
	var dl = DirectionalLight3D.new(); dl.rotation_degrees = Vector3(-50, 40, 0); dl.light_energy = 1.2; add_child(dl)
	var fl = DirectionalLight3D.new(); fl.rotation_degrees = Vector3(40, -130, 0); fl.light_energy = 0.5; add_child(fl)
	var bl = DirectionalLight3D.new(); bl.rotation_degrees = Vector3(0, 180, 0); bl.light_energy = 0.3; add_child(bl)


func _process(dt):
	if not _orbiting and not _panning:
		_idle_timer+=dt
		if _idle_timer>1.5: _orbit_h+=dt*8.0; _update_cam()
	if _orbiting or _panning: _idle_timer=0.0

	if _dirty:
		_compute_3d()
		_relax_3d()
		_polygonize_rings()
		_fix_substituents()
		_sync_meshes()
		_update_cam()
		# 自动缩放到合适大小
		var max_r=0.0
		for id in _pos3d: max_r=max(max_r,_pos3d[id].length())
		_orbit_dist=max(4.0,max_r*1.8)
		_update_cam()
		_dirty=false

	# 实时检测 Global 变化
	for a in Global.atoms:
		if is_instance_valid(a) and not _pos3d.has(a.id): _dirty=true; break
	for b in Global.bonds:
		var key=_bkey(b.id1,b.id2)
		if not _bonds.has(key): _dirty=true; break
	if _dirty: return

	# 键角更新
	if _hovered_key!="":
		var d=_bonds.get(_hovered_key)
		if d and d.has("area_node"):
			d["area_node"].get_node("Label3D").text="≈%.0f°"%_calc_angle(d["bond_ref"])


# ============================================================
# 3D 几何生成
# ============================================================

func _compute_3d():
	_pos3d.clear()
	if Global.atoms.is_empty(): return

	# 找根原子（键最多）
	var root=null; var max_d=0
	for a in Global.atoms:
		if is_instance_valid(a) and a.neighbors.size()>max_d:
			max_d=a.neighbors.size(); root=a
	if root==null: return

	_pos3d[root.id]=Vector3.ZERO
	_place_children(root.id, _pos3d[root.id], -1, Vector3.FORWARD, Vector3.UP)


func _place_children(aid:int, pos:Vector3, from_id:int, ref_dir:Vector3, up:Vector3):
	var a=_find(aid); if a==null: return
	var nbs=[]; for nb_id in a.neighbors: if nb_id!=from_id: nbs.append(nb_id)
	if nbs.is_empty(): return

	var geom=_geometry(a)
	var dirs=_gen_directions(geom, nbs.size(), ref_dir, up)

	for i in range(nbs.size()):
		var nb_id=nbs[i]
		if _pos3d.has(nb_id): continue
		var dir=dirs[i]
		var nb=_find(nb_id)
		var new_up=up
		if nb: new_up=(dir.cross(up)).normalized()
		_pos3d[nb_id]=pos+dir*BOND_LEN
		_place_children(nb_id,_pos3d[nb_id],aid,dir,new_up)


func _relax_3d():
	var ids=[]; for id in _pos3d: ids.append(id)
	if ids.size()<2: return
	for _iter in range(20):
		var forces={}; for id in ids: forces[id]=Vector3.ZERO
		for b in Global.bonds:
			if not _pos3d.has(b.id1) or not _pos3d.has(b.id2): continue
			var d=_pos3d[b.id1].distance_to(_pos3d[b.id2])
			if d<0.01: continue
			var dir=(_pos3d[b.id2]-_pos3d[b.id1])/d
			var f=dir*(d-BOND_LEN)*0.35
			forces[b.id1]+=f; forces[b.id2]-=f
		for i in range(ids.size()):
			for j in range(i+1,ids.size()):
				var a=ids[i]; var bb=ids[j]
				var bonded=false
				for bo in Global.bonds:
					if (bo.id1==a and bo.id2==bb) or (bo.id1==bb and bo.id2==a):
						bonded=true; break
				if bonded: continue
				var d=_pos3d[a].distance_to(_pos3d[bb])
				if d<0.01 or d>BOND_LEN*2.2: continue
				var dir2=(_pos3d[a]-_pos3d[bb])/d
				var f2=dir2*(BOND_LEN*1.4-d)*0.06
				forces[a]+=f2; forces[bb]-=f2
		for id in ids: _pos3d[id]+=forces[id]


func _polygonize_rings():
	var groups=_find_ring_groups()
	for group in groups:
		var n=group.size()
		if n<3: continue
		# 按环序排列
		group=_order_ring(group)
		n=group.size()
		var cnt=Vector3.ZERO
		for id in group: cnt+=_pos3d[id]
		cnt/=float(n)
		var normal=Vector3.UP
		if n>=3:
			var v1=_pos3d[group[1]]-_pos3d[group[0]]
			var v2=_pos3d[group[2]]-_pos3d[group[0]]
			normal=v1.cross(v2).normalized()
		var u=(_pos3d[group[0]]-cnt).normalized()
		if u.length()<0.01: u=Vector3.RIGHT
		var vv=normal.cross(u).normalized()
		var tr=BOND_LEN*0.5/sin(PI/float(n))
		for i in range(n):
			var ang=TAU*float(i)/float(n)
			_pos3d[group[i]]=cnt+(u*cos(ang)+vv*sin(ang))*tr


func _order_ring(group:Array)->Array:
	if group.size()<3: return group
	var start=group[0]; var ordered=[start]
	var visited={start:true}; var cur=start
	while ordered.size()<group.size():
		var found=false
		for nb_id in _find(cur).neighbors:
			if nb_id in group and not visited.get(nb_id,false):
				ordered.append(nb_id); visited[nb_id]=true; cur=nb_id; found=true; break
		if not found: break
	return ordered


func _fix_substituents():
	# 找所有环组，将环上取代基（H 等）放到环外侧
	var groups=_find_ring_groups()
	for group in groups:
		if group.size()<3: continue
		var cnt=Vector3.ZERO
		for id in group: cnt+=_pos3d[id]
		cnt/=float(group.size())
		for id in group:
			if not _pos3d.has(id): continue
			var outdir=(_pos3d[id]-cnt).normalized()
			if outdir.length()<0.01: outdir=Vector3.RIGHT
			var ring_atom=_find(id)
			if ring_atom==null: continue
			for nb_id in ring_atom.neighbors:
				if nb_id in group: continue
				if not _pos3d.has(nb_id): continue
				_pos3d[nb_id]=_pos3d[id]+outdir*BOND_LEN


func _find_ring_groups()->Array:
	# 找出所有环碳（≥2碳邻居），BFS分组
	var ring_ids=[]
	for a in Global.atoms:
		if is_instance_valid(a) and a.symbol=="C":
			var cn=0
			for nb_id in a.neighbors:
				var nb=_find(nb_id)
				if nb and nb.symbol=="C": cn+=1
			if cn>=2: ring_ids.append(a.id)
	if ring_ids.size()<3: return []

	var visited={}
	var groups=[]
	for rid in ring_ids:
		if visited.get(rid,false): continue
		var group=[]
		var queue=[rid]; visited[rid]=true
		while queue.size()>0:
			var cur=queue.pop_front(); group.append(cur)
			for nb_id in _find(cur).neighbors:
				if nb_id in ring_ids and not visited.get(nb_id,false):
					visited[nb_id]=true; queue.append(nb_id)
		if group.size()>=3: groups.append(group)
	return groups


func _geometry(atom)->String:
	if atom.symbol=="C":
		var dbl=0
		for b in Global.bonds:
			if (b.id1==atom.id or b.id2==atom.id) and b.get("bond_type",1)>=2: dbl+=1
		if dbl>=2 or atom.neighbors.size()==2: return "linear"
		if dbl==1 or atom.neighbors.size()==3: return "trigonal"
		return "tetrahedral"
	if atom.symbol=="N":
		if atom.neighbors.size()>=3: return "trigonal"
		return "bent"
	if atom.symbol=="O":
		return "bent"
	return "tetrahedral"


func _gen_directions(geom:String, n:int, ref:Vector3, up:Vector3)->Array:
	var dirs=[]
	match geom:
		"linear":
			dirs=[ref,-ref]
		"trigonal":
			var r=ref.normalized(); var u=up.normalized()
			var v=(r.cross(u)).normalized()
			dirs=[r,(-0.5*r+0.866*v).normalized(),(-0.5*r-0.866*v).normalized()]
		"bent":
			var r=ref.normalized(); var u=up.normalized()
			var v=(r.cross(u)).normalized()
			dirs=[(-0.45*r+0.893*v).normalized(),(-0.45*r-0.893*v).normalized()]
		"tetrahedral":
			var t=ref.normalized(); var q=up.normalized()
			var s=(t.cross(q)).normalized()
			dirs=[
				t,
				(-0.333*t+0.943*s).normalized(),
				(-0.333*t-0.471*s+0.816*q).normalized(),
				(-0.333*t-0.471*s-0.816*q).normalized(),
			]
	while dirs.size()<n:
		dirs.append(dirs[0])  # 兜底
	var out=[]; for i in range(min(n,dirs.size())): out.append(dirs[i])
	return out


# ============================================================
# 网格同步
# ============================================================

func _sync_meshes():
	# 原子
	for a in Global.atoms:
		if not is_instance_valid(a): continue
		if not _atoms.has(a.id): _atoms[a.id]=_make_ball(a)
		_atoms[a.id].position=_pos3d.get(a.id,Vector3.ZERO)
	# 清理已删原子
	var ad=[]; for aid in _atoms:
		var found=false
		for ga in Global.atoms: if is_instance_valid(ga) and ga.id==aid: found=true; break
		if not found: ad.append(aid)
	for aid in ad:
		if is_instance_valid(_atoms[aid]): _atoms[aid].queue_free()
		_atoms.erase(aid); _pos3d.erase(aid)

	# 键
	var bseen={}
	for b in Global.bonds:
		var key=_bkey(b.id1,b.id2); bseen[key]=true
		if not _pos3d.has(b.id1) or not _pos3d.has(b.id2): continue
		if not _bonds.has(key):
			_bonds[key]=_make_stick(b,_pos3d[b.id1],_pos3d[b.id2])
		else:
			_update_stick(_bonds[key],_pos3d[b.id1],_pos3d[b.id2])
	var bd=[]; for key in _bonds:
		if not bseen.get(key,false): bd.append(key)
	for key in bd:
		var d=_bonds[key]
		if is_instance_valid(d["node"]): d["node"].queue_free()
		_bonds.erase(key)
		if _hovered_key==key: _hovered_key=""


# ============================================================
# 构建
# ============================================================

func _make_ball(atom)->Node3D:
	var n=Node3D.new()
	var m=MeshInstance3D.new()
	var sm=SphereMesh.new(); sm.radius=BALL_R; sm.height=BALL_R*2; sm.radial_segments=24; sm.rings=16
	m.mesh=sm
	var mat=StandardMaterial3D.new()
	mat.albedo_color=Global.get_color(atom.symbol)
	mat.metallic=0.35; mat.roughness=0.2
	m.material_override=mat
	n.add_child(m)
	add_child(n)
	return n


func _make_stick(bond,p1:Vector3,p2:Vector3)->Dictionary:
	var dir=(p2-p1).normalized()
	var ep1=p1+dir*BALL_R; var ep2=p2-dir*BALL_R
	var mid=(ep1+ep2)/2.0; var len=ep1.distance_to(ep2)
	if len<0.01: len=0.01

	var node=Node3D.new()
	var mesh=MeshInstance3D.new(); mesh.name="Cylinder"
	var cm=CylinderMesh.new(); cm.top_radius=STICK_R; cm.bottom_radius=STICK_R; cm.height=1.0
	mesh.mesh=cm
	var mat=StandardMaterial3D.new(); mat.albedo_color=Color(0.18,0.18,0.18); mat.metallic=0.2; mat.roughness=0.5
	mesh.material_override=mat
	node.add_child(mesh)

	var area=Area3D.new()
	var col=CollisionShape3D.new()
	var cs=CylinderShape3D.new(); cs.radius=STICK_R*2.2; cs.height=1.0; col.shape=cs
	area.add_child(col)
	area.set_meta("bond_ids",[bond.id1,bond.id2])
	area.mouse_entered.connect(_on_enter.bind(bond)); area.mouse_exited.connect(_on_exit)
	node.add_child(area)

	var lbl=Label3D.new(); lbl.name="Label3D"; lbl.text=""; lbl.font_size=28
	lbl.billboard=BaseMaterial3D.BILLBOARD_ENABLED; lbl.modulate=Color(1,0.9,0.3)
	area.add_child(lbl)

	add_child(node)
	_update_stick({"node":node,"area_node":area},ep1,ep2)
	return {"node":node,"area_node":area,"bond_ref":bond}


func _update_stick(d:Dictionary,p1:Vector3,p2:Vector3):
	var dir=(p2-p1).normalized(); var mid=(p1+p2)/2.0; var len=p1.distance_to(p2)
	var node=d["node"]; node.position=mid
	var mesh=node.get_node("Cylinder"); mesh.scale=Vector3(1,len,1)
	var up=Vector3.UP
	if abs(dir.dot(up))>0.999:
		node.rotation=Vector3(PI,0,0) if dir.dot(up)<0 else Vector3.ZERO
	else:
		node.look_at(mid+dir,Vector3.UP); node.rotate_object_local(Vector3(1,0,0),-PI/2)
	var area=d["area_node"]; var col=area.get_child(0)
	col.shape.height=len; col.shape.radius=STICK_R*2.2
	area.get_node("Label3D").position=Vector3(0,len*0.5,0)


# ============================================================
# 相机
# ============================================================

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			_orbiting=true; _drag_start=event.position
		elif event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			_orbiting=false
		elif event.button_index==MOUSE_BUTTON_MIDDLE and event.pressed:
			_panning=true; _drag_start=event.position
		elif event.button_index==MOUSE_BUTTON_MIDDLE and not event.pressed:
			_panning=false
		elif event.button_index==MOUSE_BUTTON_WHEEL_UP:
			_orbit_dist=max(3.0,_orbit_dist-1.0); _update_cam()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_dist=min(30.0,_orbit_dist+1.0); _update_cam()
	if event is InputEventMouseMotion:
		var delta=event.position-_drag_start; _drag_start=event.position
		if _orbiting:
			_orbit_h-=delta.x*0.3; _orbit_v=clamp(_orbit_v-delta.y*0.3,-80,80); _update_cam()
		elif _panning:
			var r=_cam.global_transform.basis.x; var u=_cam.global_transform.basis.y
			_cam_target-=(r*delta.x+u*delta.y)*_orbit_dist*0.002; _update_cam()

func _update_cam():
	var y=_orbit_dist*sin(deg_to_rad(_orbit_v))
	var xz=_orbit_dist*cos(deg_to_rad(_orbit_v))
	_cam.position=_cam_target+Vector3(xz*sin(deg_to_rad(_orbit_h)),y,xz*cos(deg_to_rad(_orbit_h)))
	_cam.look_at(_cam_target)


# ============================================================
# 悬停与键角
# ============================================================

var _hovered_key: String = ""

func _on_enter(bond):
	_hovered_key=_bkey(bond.id1,bond.id2)
	var ang=_calc_angle(bond)
	bond_hovered.emit([bond.id1,bond.id2],ang)

func _on_exit():
	_hovered_key=""
	bond_unhovered.emit()

func _calc_angle(bond)->float:
	var a1=_find(bond.id1); var a2=_find(bond.id2)
	if not a1 or not a2: return 0
	var angles=[]
	var v1=(_pos3d.get(a2.id)-_pos3d.get(a1.id)).normalized()
	for nb_id in a1.neighbors:
		if nb_id==a2.id: continue
		if _pos3d.has(nb_id):
			var v2=(_pos3d[nb_id]-_pos3d[a1.id]).normalized()
			angles.append(rad_to_deg(acos(clamp(v1.dot(v2),-1,1))))
	if angles.is_empty(): return 0
	angles.sort(); return angles[0]


# ============================================================
# 工具
# ============================================================

func _bkey(id1:int,id2:int)->String: return str(min(id1,id2))+"_"+str(max(id1,id2))

func _find(id:int):
	for a in Global.atoms:
		if is_instance_valid(a) and a.id==id: return a
	return null

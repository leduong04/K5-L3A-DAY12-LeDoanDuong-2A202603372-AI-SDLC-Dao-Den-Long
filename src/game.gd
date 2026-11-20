extends Node3D

const Sim = preload("res://src/simulation.gd")
const FIXED_DT := 1.0 / 60.0
var sim
var player_visual: Node3D
var hud: Label
var hint: Label
var lantern_nodes: Array[Node3D] = []
var mote_nodes: Array[Node3D] = []
var shade_nodes: Array[Node3D] = []
var accumulator := 0.0
var restart_was_down := false

func _ready() -> void:
	sim = Sim.new()
	sim.setup(int(Time.get_ticks_usec()))
	_build_world()
	_build_hud()
	_refresh_visuals()

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("111633")
	sky_mat.sky_horizon_color = Color("4a355b")
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("77708c")
	environment.ambient_light_energy = 0.45
	env.environment = environment
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, -30, 0)
	moon.light_color = Color("b9baff")
	moon.light_energy = 0.55
	add_child(moon)
	var island := MeshInstance3D.new()
	var island_mesh := CylinderMesh.new()
	island_mesh.top_radius = 32
	island_mesh.bottom_radius = 27
	island_mesh.height = 2
	island.mesh = island_mesh
	island.position.y = -1
	island.material_override = _mat(Color("28344c"), 0.08)
	add_child(island)
	var grass := MeshInstance3D.new()
	var grass_mesh := CylinderMesh.new()
	grass_mesh.top_radius = 31
	grass_mesh.bottom_radius = 31
	grass_mesh.height = 0.18
	grass.mesh = grass_mesh
	grass.position.y = -0.05
	grass.material_override = _mat(Color("344c4a"), 0.12)
	add_child(grass)
	var water := MeshInstance3D.new()
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 100
	water_mesh.bottom_radius = 100
	water_mesh.height = 0.2
	water.mesh = water_mesh
	water.position.y = -2.2
	water.material_override = _mat(Color("161d39"), 0.15)
	add_child(water)
	for i in range(12):
		var rock := _sphere("Far cloud %d" % i, Vector3(1.7, 0.55, 1.7), Color("666383"), 0.0)
		var a := TAU * float(i) / 12.0
		rock.position = Vector3(cos(a) * 36, -0.65 + sin(a * 3.0) * 0.25, sin(a) * 36)
		add_child(rock)
	for lantern in sim.lanterns:
		var root := Node3D.new()
		root.position = lantern.pos
		add_child(root)
		var stem := _cylinder("Lantern post", 0.22, 2.2, Color("49383b"), 0.0)
		stem.position.y = 1.1
		root.add_child(stem)
		var bulb := _sphere("Warm lantern", Vector3(0.58, 0.72, 0.58), Color("ffae49"), 1.0)
		bulb.position.y = 2.35
		root.add_child(bulb)
		var light := OmniLight3D.new()
		light.position.y = 2.35
		light.light_color = Color("ffad4d")
		light.light_energy = 0.0
		light.omni_range = 8
		root.add_child(light)
		root.set_meta("light", light)
		lantern_nodes.append(root)
	for mote in sim.motes:
		var node := _sphere("Firefly", Vector3(0.34, 0.34, 0.34), Color("baff75"), 1.2)
		node.position = mote.pos + Vector3.UP * 0.7
		add_child(node)
		mote_nodes.append(node)
	for shade in sim.shades:
		var node := _sphere("Ink Shade", Vector3(0.9, 1.25, 0.9), Color("30203f"), 0.2)
		node.position = shade.pos
		add_child(node)
		shade_nodes.append(node)
	player_visual = Node3D.new()
	add_child(player_visual)
	var body := _sphere("May", Vector3(0.7, 1.15, 0.55), Color("e6aa82"), 0.0)
	body.position.y = 0.8
	player_visual.add_child(body)
	var hat := _cylinder("Non la", 0.92, 0.18, Color("d4ad65"), 0.0)
	hat.position.y = 1.48
	player_visual.add_child(hat)
	var hat_top := _sphere("Hat crown", Vector3(0.44, 0.28, 0.44), Color("d4ad65"), 0.0)
	hat_top.position.y = 1.65
	player_visual.add_child(hat_top)
	var little_lamp := _sphere("May's lamp", Vector3(0.23, 0.3, 0.23), Color("ffbd57"), 1.0)
	little_lamp.position = Vector3(0.43, 0.85, -0.25)
	player_visual.add_child(little_lamp)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 6, 11)
	camera.rotation_degrees.x = 25
	camera.current = true
	player_visual.add_child(camera)
	var player_light := OmniLight3D.new()
	player_light.position = Vector3(0.4, 1.2, 0)
	player_light.light_color = Color("ffbb67")
	player_light.light_energy = 0.8
	player_light.omni_range = 5
	player_visual.add_child(player_light)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color("fff1cf"))
	layer.add_child(hud)
	hint = Label.new()
	hint.position = Vector2(24, 650)
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("e8d9ff"))
	hint.text = "WASD di chuyển · Space nhảy · E thắp đèn · Q tỏa sáng · R chơi lại"
	layer.add_child(hint)

func _process(delta: float) -> void:
	if sim.state != "playing":
		var restart_down := Input.is_key_pressed(KEY_R)
		if restart_down and not restart_was_down: _restart()
		restart_was_down = restart_down
		return
	var move := Vector2.ZERO
	move.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	move.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	var jump_down := Input.is_key_pressed(KEY_SPACE)
	var interact_down := Input.is_key_pressed(KEY_E)
	var pulse_down := Input.is_key_pressed(KEY_Q)
	# In-game controls use the contract's camera-relative basis; the camera follows behind +Z.
	sim.set_controls(move, 0.0, jump_down, interact_down, pulse_down)
	accumulator += delta
	while accumulator >= FIXED_DT:
		sim.step()
		accumulator -= FIXED_DT
	_refresh_visuals()

func _refresh_visuals() -> void:
	player_visual.position = sim.player_pos
	for i in range(lantern_nodes.size()):
		var lamp: Dictionary = sim.lanterns[i]
		var light: OmniLight3D = lantern_nodes[i].get_meta("light")
		light.light_energy = 2.0 if lamp.lit else 0.0
		var bulb: MeshInstance3D = lantern_nodes[i].get_child(1)
		var bulb_material := bulb.material_override as StandardMaterial3D
		bulb_material.albedo_color = Color("ffae49") if lamp.lit else Color("55494b")
		bulb_material.emission_enabled = lamp.lit
		lantern_nodes[i].position = lamp.pos
	if mote_nodes.size() != sim.motes.size():
		for old in mote_nodes: old.queue_free()
		mote_nodes.clear()
		for mote in sim.motes:
			var node := _sphere("Firefly", Vector3(0.34, 0.34, 0.34), Color("baff75"), 1.2)
			add_child(node)
			mote_nodes.append(node)
	for i in range(mini(mote_nodes.size(), sim.motes.size())):
		mote_nodes[i].position = sim.motes[i].pos + Vector3.UP * (0.7 + sin(float(Time.get_ticks_msec()) * 0.004 + i) * 0.18)
	if shade_nodes.size() != sim.shades.size():
		for old in shade_nodes: old.queue_free()
		shade_nodes.clear()
		for _shade in sim.shades:
			var node := _sphere("Ink Shade", Vector3(0.9, 1.25, 0.9), Color("30203f"), 0.2)
			add_child(node)
			shade_nodes.append(node)
	for i in range(mini(shade_nodes.size(), sim.shades.size())):
		shade_nodes[i].position = sim.shades[i].pos
		var shade_material := shade_nodes[i].material_override as StandardMaterial3D
		shade_material.albedo_color = Color("9286ff") if sim.shades[i].state == "stunned" else Color("30203f")
	hud.text = "ĐÊM 1 · %.0fs\nĐom đóm %d/%d · Đèn %d/5 · Lửa %d · Điểm %d" % [sim.time_left, sim.carried, Sim.CAPACITY, _lit_count(), sim.flames, sim.score]
	if sim.state != "playing":
		hint.text = ("ĐẢO SÁNG TRỞ LẠI!  Điểm: %d\nR để chơi lại" if sim.state == "won" else "ĐÊM NUỐT LẤY ÁNH SÁNG…  Điểm: %d\nR để chơi lại") % sim.score

func _lit_count() -> int:
	var n := 0
	for l in sim.lanterns:
		if l.lit: n += 1
	return n

func _restart() -> void:
	get_tree().reload_current_scene()

func _mat(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emission > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func _sphere(label: String, size: Vector3, color: Color, emission: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	node.mesh = mesh
	node.scale = size
	node.material_override = _mat(color, emission)
	return node

func _cylinder(label: String, radius: float, height: float, color: Color, emission: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = _mat(color, emission)
	return node

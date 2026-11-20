extends SceneTree

const Sim = preload("res://src/simulation.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Missing headless arguments after --")
		quit(2)
		return
	var options := _parse_options(args)
	if options.has("error"):
		push_error(options.error)
		quit(2)
		return
	_run(options)

func _parse_options(args: PackedStringArray) -> Dictionary:
	var result := {"seed": 1, "night": 1, "ticks": -1, "snapshot_every": 10, "out": "", "scenario": "", "inputs": ""}
	var supplied: Array[String] = []
	var i := 0
	while i < args.size():
		var key := args[i]
		if not ["--seed", "--night", "--ticks", "--snapshot-every", "--out", "--scenario", "--inputs"].has(key):
			return {"error": "Unknown argument: %s" % key}
		if i + 1 >= args.size(): return {"error": "Missing value for %s" % key}
		var value := args[i + 1]
		supplied.append(key)
		if key in ["--seed", "--night", "--ticks", "--snapshot-every"] and not value.is_valid_int():
			return {"error": "%s must be an integer" % key}
		match key:
			"--seed": result.seed = value.to_int()
			"--night": result.night = value.to_int()
			"--ticks": result.ticks = value.to_int()
			"--snapshot-every": result.snapshot_every = value.to_int()
			"--out": result.out = value
			"--scenario": result.scenario = value
			"--inputs": result.inputs = value
		i += 2
	for required in ["--seed", "--night", "--ticks", "--out"]:
		if not supplied.has(required): return {"error": "%s is required" % required}
	if result.night != 1: return {"error": "Only --night 1 is supported in Phase 1"}
	if result.ticks < 0: return {"error": "--ticks must be a non-negative integer"}
	if result.snapshot_every <= 0: return {"error": "--snapshot-every must be positive"}
	if result.out == "": return {"error": "--out is required"}
	return result

func _run(options: Dictionary) -> void:
	var scenario := {}
	var inputs := {"frames": []}
	if options.scenario != "":
		var parsed_scenario := _read_json(options.scenario)
		if parsed_scenario.has("error"):
			push_error(parsed_scenario.error)
			quit(2)
			return
		if not parsed_scenario.value is Dictionary:
			push_error("Scenario root must be an object")
			quit(2)
			return
		scenario = parsed_scenario.value
		var validation := _validate_scenario(scenario)
		if validation != "":
			push_error(validation)
			quit(2)
			return
	if options.inputs != "":
		var parsed_inputs := _read_json(options.inputs)
		if parsed_inputs.has("error"):
			push_error(parsed_inputs.error)
			quit(2)
			return
		if not parsed_inputs.value is Dictionary or not parsed_inputs.value.get("frames", []) is Array:
			push_error("Inputs must be an object containing a frames array")
			quit(2)
			return
		inputs = parsed_inputs.value
		if inputs.frames.size() > 0:
			for input_frame in inputs.frames:
				if not input_frame is Dictionary or not input_frame.has("tick") or not _is_integer(input_frame.tick) or int(input_frame.tick) < 0:
					push_error("Each input frame requires a non-negative integer tick")
					quit(2)
					return
				if input_frame.has("cam_yaw_deg") and not _is_number(input_frame.cam_yaw_deg):
					push_error("cam_yaw_deg must be numeric")
					quit(2)
					return
	var frames: Array = inputs.get("frames", [])
	var previous_tick := -1
	for input_frame in frames:
		if not input_frame is Dictionary or not input_frame.has("tick") or int(input_frame.tick) <= previous_tick:
			push_error("Input frame ticks must be strictly increasing integers")
			quit(2)
			return
		previous_tick = int(input_frame.tick)
		if input_frame.has("move") and (not input_frame.move is Array or input_frame.move.size() != 2 or not _is_number(input_frame.move[0]) or not _is_number(input_frame.move[1]) or absf(float(input_frame.move[0])) > 1.0 or absf(float(input_frame.move[1])) > 1.0):
			push_error("move must be [x,z] with both components in [-1,1]")
			quit(2)
			return
		for action in ["jump", "interact", "pulse"]:
			if input_frame.has(action) and not input_frame[action] is bool:
				push_error("%s must be boolean" % action)
				quit(2)
				return
	var sim = Sim.new()
	sim.setup(int(options.seed), scenario)
	var output := FileAccess.open(options.out, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write output file: %s" % options.out)
		quit(1)
		return
	var frame_index := 0
	var controls := {"move": Vector2.ZERO, "yaw": 0.0, "jump": false, "interact": false, "pulse": false}
	output.store_line(JSON.stringify(sim.snapshot()))
	for step_index in range(int(options.ticks)):
		while frame_index < frames.size() and int(frames[frame_index].tick) == step_index:
			var active_frame: Dictionary = frames[frame_index]
			if active_frame.has("move"): controls.move = Vector2(float(active_frame.move[0]), float(active_frame.move[1]))
			if active_frame.has("cam_yaw_deg"): controls.yaw = float(active_frame.cam_yaw_deg)
			for action in ["jump", "interact", "pulse"]:
				if active_frame.has(action): controls[action] = active_frame[action]
			frame_index += 1
		sim.set_controls(controls.move, controls.yaw, controls.jump, controls.interact, controls.pulse)
		sim.step()
		for event in sim.events:
			output.store_line(JSON.stringify({"type": "event", "tick": sim.tick, "name": event.name, "data": event.data}))
		if sim.tick % int(options.snapshot_every) == 0: output.store_line(JSON.stringify(sim.snapshot()))
		if sim.state != "playing": break
	output.store_line(JSON.stringify({"type": "end", "ticks": sim.tick, "state": sim.state, "score": sim.score}))
	output.close()
	quit(0)

func _validate_scenario(value: Dictionary) -> String:
	if value.has("player"):
		if not value.player is Dictionary: return "scenario.player must be an object"
		var p: Dictionary = value.player
		if p.has("pos") and not _is_vec3(p.pos): return "player.pos must contain three numbers"
		for key in ["carried", "flames"]:
			if p.has(key) and (not _is_integer(p[key]) or int(p[key]) < 0): return "player.%s must be a non-negative integer" % key
	for key in ["random_motes", "random_shades"]:
		if value.has(key) and not value[key] is bool: return "%s must be boolean" % key
	if value.has("time_left_s") and (not _is_number(value.time_left_s) or float(value.time_left_s) < 0): return "time_left_s must be non-negative"
	if value.has("motes"):
		if not value.motes is Array: return "motes must be an array"
		for mote_pos in value.motes:
			if not _is_vec3(mote_pos): return "each mote position must contain three numbers"
	if value.has("shades"):
		if not value.shades is Array: return "shades must be an array"
		for shade in value.shades:
			if not shade is Dictionary or (shade.has("pos") and not _is_vec3(shade.pos)): return "each shade must have a valid position"
			if shade.has("id") and not shade.id is String: return "shade id must be a string"
	if value.has("lanterns"):
		if not value.lanterns is Array: return "lanterns must be an array"
		for lantern in value.lanterns:
			if not lantern is Dictionary or not lantern.has("id") or not lantern.id is String: return "each lantern update requires a string id"
			if not ["L1", "L2", "L3", "L4", "L5"].has(lantern.id): return "unknown lantern id: %s" % lantern.id
			if lantern.has("pos") and not _is_vec3(lantern.pos): return "lantern.pos must contain three numbers"
			if lantern.has("deposited") and (not _is_integer(lantern.deposited) or int(lantern.deposited) < 0 or int(lantern.deposited) > 3): return "lantern.deposited must be an integer from 0 to 3"
			if lantern.has("lit") and not lantern.lit is bool: return "lantern.lit must be boolean"
	return ""

func _is_vec3(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	return _is_number(value[0]) and _is_number(value[1]) and _is_number(value[2])

func _is_number(value: Variant) -> bool:
	return value is int or value is float

func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, floor(value)))

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"error": "File does not exist: %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error": "Cannot read file: %s" % path}
	var parser := JSON.new()
	var error_code := parser.parse(file.get_as_text())
	if error_code != OK: return {"error": "%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()]}
	return {"value": parser.data}

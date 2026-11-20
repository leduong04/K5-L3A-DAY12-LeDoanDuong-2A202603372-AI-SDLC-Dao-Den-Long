class_name GameSimulation
extends RefCounted

const DT := 1.0 / 60.0
const CAPACITY := 5
const LANTERN_COST := 3
const PLAYER_SPEED := 6.0
const PICKUP_RADIUS := 1.25
const INTERACT_RADIUS := 2.0
const PULSE_COST := 1
const PULSE_RADIUS := 6.0
const NIGHT_SECONDS := 300.0
const START_FLAMES := 3
const INVULN_SECONDS := 1.5
const PULSE_STUN_SECONDS := 2.0
const PULSE_PUSH := 2.5
const PULSE_COOLDOWN := 1.0
const SAFE_RADIUS := 4.0
const SHADE_SPEED := 2.2
const SHADE_HIT_RADIUS := 1.0

var rng := RandomNumberGenerator.new()
var tick := 0
var state := "playing"
var score := 0
var player_pos := Vector3.ZERO
var carried := 0
var flames := START_FLAMES
var invuln_ticks := 0
var pulse_cooldown_ticks := 0
var time_left := NIGHT_SECONDS
var motes: Array[Dictionary] = []
var shades: Array[Dictionary] = []
var lanterns: Array[Dictionary] = []
var events: Array[Dictionary] = []
var random_motes := true
var random_shades := true
var next_mote_id := 1
var next_shade_id := 1
var input_move := Vector2.ZERO
var input_yaw := 0.0
var input_jump := false
var input_interact := false
var input_pulse := false
var jump_velocity := 0.0
var previous_jump := false
var previous_interact := false
var previous_pulse := false

func setup(seed_value: int, scenario: Dictionary = {}) -> void:
	rng.seed = seed_value
	for i in range(5):
		var lantern_angle := TAU * float(i) / 5.0
		lanterns.append({"id": "L%d" % (i + 1), "pos": Vector3(cos(lantern_angle) * 20.0, 0, sin(lantern_angle) * 20.0), "lit": false, "deposited": 0})
	for i in range(12):
		var mote_angle := rng.randf_range(0, TAU)
		var radius := rng.randf_range(5, 27)
		_add_mote(Vector3(cos(mote_angle) * radius, 0, sin(mote_angle) * radius))
	for i in range(3):
		var shade_angle := TAU * float(i) / 3.0 + 0.4
		shades.append({"id": "S%d" % (i + 1), "pos": Vector3(cos(shade_angle) * 30.0, 1, sin(shade_angle) * 30.0), "state": "chase", "stun": 0})
	if scenario.is_empty():
		return
	if scenario.has("player"):
		var p: Dictionary = scenario.player
		player_pos = _vec(p.get("pos", [0, 0, 0]))
		carried = int(p.get("carried", 0))
		flames = int(p.get("flames", START_FLAMES))
	if scenario.has("time_left_s"):
		time_left = float(scenario.time_left_s)
	random_motes = bool(scenario.get("random_motes", true))
	random_shades = bool(scenario.get("random_shades", true))
	if not random_motes and not scenario.has("motes"): motes.clear()
	if not random_shades and not scenario.has("shades"): shades.clear()
	if scenario.has("motes"):
		motes.clear()
		next_mote_id = 1
		for position in scenario.motes:
			_add_mote(_vec(position))
	if scenario.has("shades"):
		shades.clear()
		next_shade_id = 1
		for item in scenario.shades:
			var pos := _vec(item.get("pos", [0, 0, 0]))
			var sid := _allocate_shade_id()
			if item.has("id"):
				sid = str(item.id)
				var numeric_id := sid.trim_prefix("S")
				if numeric_id.is_valid_int(): next_shade_id = maxi(next_shade_id, int(numeric_id) + 1)
			shades.append({"id": sid, "pos": pos, "state": "chase", "stun": 0})
	if scenario.has("lanterns"):
		for change in scenario.lanterns:
			for lantern in lanterns:
				if lantern.id == str(change.get("id", "")):
					if change.has("pos"): lantern.pos = _vec(change.pos)
					if change.has("deposited"): lantern.deposited = int(change.deposited)
					if change.has("lit"): lantern.lit = bool(change.lit)
					elif lantern.deposited >= LANTERN_COST: lantern.lit = true
					break

func set_controls(move: Vector2, yaw_degrees: float, jump: bool, interact: bool, pulse: bool) -> void:
	input_move = move.clamp(Vector2(-1, -1), Vector2(1, 1))
	if input_move.length() > 1.0: input_move = input_move.normalized()
	input_yaw = yaw_degrees
	input_jump = jump
	input_interact = interact
	input_pulse = pulse

func step() -> void:
	if state != "playing": return
	events.clear()
	var angle := deg_to_rad(input_yaw)
	var world := Vector2(input_move.x * cos(angle) + input_move.y * sin(angle), -input_move.x * sin(angle) + input_move.y * cos(angle))
	player_pos.x += world.x * PLAYER_SPEED * DT
	player_pos.z += world.y * PLAYER_SPEED * DT
	if invuln_ticks > 0: invuln_ticks -= 1
	if pulse_cooldown_ticks > 0: pulse_cooldown_ticks -= 1
	if input_jump and not previous_jump and player_pos.y <= 0.0:
		jump_velocity = 7.0
	if player_pos.y > 0.0 or jump_velocity > 0.0:
		jump_velocity -= 18.0 * DT
		player_pos.y = maxf(0.0, player_pos.y + jump_velocity * DT)
		if player_pos.y == 0.0: jump_velocity = 0.0
	if input_interact and not previous_interact: _interact()
	if input_pulse and not previous_pulse: _pulse()
	previous_jump = input_jump
	previous_interact = input_interact
	previous_pulse = input_pulse
	_update_motes()
	_update_shades()
	tick += 1
	time_left = maxf(0.0, time_left - DT)
	if state == "playing" and _all_lit(): _finish("won", "all_lit")
	elif state == "playing" and flames <= 0: _finish("lost", "no_flames")
	elif state == "playing" and time_left <= 0.0: _finish("lost", "dawn")
	if state == "playing" and random_motes and tick % 240 == 0 and motes.size() < 30:
		var mote_angle := rng.randf_range(0, TAU)
		var mote_radius := rng.randf_range(5, 28)
		_add_mote(Vector3(cos(mote_angle) * mote_radius, 0, sin(mote_angle) * mote_radius))
	if state == "playing" and random_shades and tick % 900 == 0:
		var shade_angle := rng.randf_range(0, TAU)
		var sid := _allocate_shade_id()
		shades.append({"id": sid, "pos": Vector3(cos(shade_angle) * 30, 1, sin(shade_angle) * 30), "state": "chase", "stun": 0})
		events.append({"name": "shade_spawned", "data": {"id": sid}})

func _interact() -> void:
	var nearest := -1
	var nearest_dist := INF
	for i in range(lanterns.size()):
		var d := _flat_distance(player_pos, lanterns[i].pos)
		if d <= INTERACT_RADIUS and d < nearest_dist:
			nearest = i
			nearest_dist = d
	if nearest < 0: return
	var lantern: Dictionary = lanterns[nearest]
	if lantern.lit or carried <= 0: return
	var amount := mini(carried, LANTERN_COST - int(lantern.deposited))
	if amount <= 0: return
	carried -= amount
	lantern.deposited += amount
	events.append({"name": "deposit", "data": {"lantern_id": lantern.id, "amount": amount, "deposited": lantern.deposited}})
	if lantern.deposited >= LANTERN_COST:
		lantern.lit = true
		score += 100
		events.append({"name": "lantern_lit", "data": {"lantern_id": lantern.id}})

func _pulse() -> void:
	if carried < PULSE_COST or pulse_cooldown_ticks > 0: return
	carried -= PULSE_COST
	pulse_cooldown_ticks = int(PULSE_COOLDOWN * 60)
	var ids: Array[String] = []
	for shade in shades:
		if _flat_distance(player_pos, shade.pos) <= PULSE_RADIUS:
			shade.state = "stunned"
			shade.stun = int(PULSE_STUN_SECONDS * 60) + 1
			var away := Vector2(shade.pos.x - player_pos.x, shade.pos.z - player_pos.z).normalized()
			var pushed_pos: Vector3 = shade.pos
			pushed_pos.x += away.x * PULSE_PUSH
			pushed_pos.z += away.y * PULSE_PUSH
			shade.pos = pushed_pos
			ids.append(shade.id)
	score += ids.size() * 15
	events.append({"name": "pulse", "data": {"stunned_ids": ids}})

func _update_motes() -> void:
	for i in range(motes.size() - 1, -1, -1):
		if carried >= CAPACITY: break
		if _flat_distance(player_pos, motes[i].pos) <= PICKUP_RADIUS:
			motes.remove_at(i)
			carried += 1
			score += 10
			events.append({"name": "mote_picked", "data": {"carried": carried}})

func _update_shades() -> void:
	for shade in shades:
		if shade.stun > 0:
			shade.stun -= 1
			if shade.stun == 0: shade.state = "chase"
			continue
		var delta := Vector2(player_pos.x - shade.pos.x, player_pos.z - shade.pos.z)
		var lantern_safe := false
		for lantern in lanterns:
			if lantern.lit and _flat_distance(shade.pos, lantern.pos) <= SAFE_RADIUS:
				lantern_safe = true
				break
		if not lantern_safe and delta.length() > 0.001:
			var direction := delta.normalized()
			var current_shade_pos: Vector3 = shade.pos
			var next_pos: Vector3 = current_shade_pos + Vector3(direction.x * SHADE_SPEED * DT, 0, direction.y * SHADE_SPEED * DT)
			var next_is_safe := false
			for lantern in lanterns:
				if lantern.lit and _flat_distance(next_pos, lantern.pos) <= SAFE_RADIUS:
					next_is_safe = true
					break
			if not next_is_safe:
				shade.pos = next_pos
		if flames > 0 and invuln_ticks == 0 and _flat_distance(shade.pos, player_pos) <= SHADE_HIT_RADIUS:
			flames -= 1
			invuln_ticks = int(INVULN_SECONDS * 60)
			var away := Vector2(player_pos.x - shade.pos.x, player_pos.z - shade.pos.z).normalized()
			player_pos.x += away.x * 2.0
			player_pos.z += away.y * 2.0
			events.append({"name": "player_hit", "data": {"by": "shade", "flames": flames, "dropped": 0}})
			break

func snapshot() -> Dictionary:
	var ls: Array[Dictionary] = []
	var ss: Array[Dictionary] = []
	for l in lanterns: ls.append({"id": l.id, "pos": _arr(l.pos), "lit": l.lit, "deposited": l.deposited})
	for s in shades: ss.append({"id": s.id, "pos": _arr(s.pos), "state": s.state})
	return {"type": "snapshot", "tick": tick, "sim_tick": tick, "state": state, "time_left_s": snappedf(time_left, 0.001), "score": score, "player": {"pos": _arr(player_pos), "flames": flames, "carried": carried}, "lanterns": ls, "shades": ss, "motes_active": motes.size()}

func _finish(result: String, reason: String) -> void:
	state = result
	if result == "won": score += int(floor(time_left)) + flames * 25
	events.append({"name": "game_over", "data": {"result": result, "reason": reason}})

func _all_lit() -> bool:
	for l in lanterns:
		if not l.lit: return false
	return true

func _add_mote(pos: Vector3) -> void:
	motes.append({"id": "M%d" % next_mote_id, "pos": pos})
	next_mote_id += 1

func _allocate_shade_id() -> String:
	var candidate := "S%d" % next_shade_id
	while true:
		var exists := false
		for shade in shades:
			if shade.id == candidate:
				exists = true
				break
		if not exists: break
		next_shade_id += 1
		candidate = "S%d" % next_shade_id
	next_shade_id += 1
	return candidate

func _vec(value: Variant) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _arr(pos: Vector3) -> Array:
	return [snappedf(pos.x, 0.001), snappedf(pos.y, 0.001), snappedf(pos.z, 0.001)]

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

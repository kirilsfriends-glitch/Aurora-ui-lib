extends Node3D

const MAP_BUILDER := preload("res://scripts/map_builder.gd")
const MAP_LIBRARY := preload("res://scripts/map_library.gd")
const PLAYER_CONTROLLER := preload("res://scripts/player_controller.gd")
const BOT_CONTROLLER := preload("res://scripts/bot_controller.gd")
const TOUCH_CONTROLS := preload("res://scripts/touch_fps_controls.gd")
const HUD := preload("res://scripts/hud.gd")
const LOBBY := preload("res://scripts/lobby.gd")
const WEAPON_DB := preload("res://scripts/weapon_database.gd")

var lobby
var hud
var touch_layer: CanvasLayer
var touch_controls
var map_runtime
var actor_root: Node3D
var local_player
var actors: Array = []
var current_mode := "tdm"
var current_map := "dockyard"
var difficulty := 0.7
var match_active := false
var round_transition := false
var match_time := 300.0
var team_scores := [0, 0]
var round_number := 1
var control_tick := 0.0
var last_hits: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    _ensure_input_actions()
    hud = HUD.new()
    add_child(hud)
    lobby = LOBBY.new()
    add_child(lobby)
    lobby.match_requested.connect(start_match)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func start_match(map_id: String, mode_id: String, bot_difficulty: float) -> void:
    _clear_match()
    current_map = map_id
    current_mode = mode_id
    difficulty = bot_difficulty
    match_active = true
    round_transition = false
    round_number = 1
    team_scores = [0, 0]
    match_time = 120.0 if current_mode == "elimination" else 300.0

    map_runtime = MAP_BUILDER.new()
    add_child(map_runtime)
    map_runtime.build(MAP_LIBRARY.get_map(current_map))
    actor_root = Node3D.new()
    actor_root.name = "Combatants"
    add_child(actor_root)
    _spawn_teams()
    _create_touch_controls()
    hud.set_match_visible(true)
    hud.clear_feed()
    hud.show_status("OPERATION START", Color("63d9d5"))
    hud.update_objective(_objective_text())
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    await get_tree().create_timer(1.4).timeout
    if match_active: hud.show_status("")

func _process(delta: float) -> void:
    if not match_active or round_transition: return
    match_time = maxf(0, match_time - delta)
    if current_mode == "control": _process_control(delta)
    hud.update_score(team_scores[0], team_scores[1], match_time, _mode_title())
    hud.update_objective(_objective_text())
    if match_time <= 0:
        if current_mode == "elimination": _end_elimination_round()
        else: _finish_match()

func _spawn_teams() -> void:
    var loadouts_alpha := ["ak47", "m4a1", "mp5", "awp", "nova"]
    var loadouts_bravo := ["m4a1", "ak47", "p90", "scout", "deagle"]
    local_player = PLAYER_CONTROLLER.new()
    actor_root.add_child(local_player)
    local_player.team = 0
    local_player.setup(self, _spawn_for(0, 0), "ak47")
    local_player.died.connect(_on_actor_died)
    local_player.health_changed.connect(hud.update_health)
    actors.append(local_player)
    for i in range(1, 5):
        _spawn_bot(0, i, loadouts_alpha[i])
    for i in range(5):
        _spawn_bot(1, i, loadouts_bravo[i])

func _spawn_bot(team_id: int, index: int, loadout: String) -> void:
    var bot := BOT_CONTROLLER.new()
    actor_root.add_child(bot)
    bot.setup(self, team_id, index, _spawn_for(team_id, index), loadout, clampf(difficulty + rng.randf_range(-0.08, 0.08), 0.35, 0.96))
    bot.died.connect(_on_actor_died)
    actors.append(bot)

func _create_touch_controls() -> void:
    touch_layer = CanvasLayer.new()
    touch_layer.layer = 15
    add_child(touch_layer)
    touch_controls = TOUCH_CONTROLS.new()
    touch_layer.add_child(touch_controls)
    touch_controls.setup(local_player)
    touch_controls.visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

func _on_actor_died(victim, killer) -> void:
    if not match_active: return
    var victim_team := int(victim.team)
    var killer_team := int(killer.team) if is_instance_valid(killer) else 1 - victim_team
    var hit_info: Dictionary = last_hits.get(victim.get_instance_id(), {})
    var headshot := bool(hit_info.get("headshot", false))
    var weapon_title := "environment"
    if is_instance_valid(killer) and killer.get("weapon") != null:
        weapon_title = str(killer.weapon.config.get("title", "weapon"))
    hud.add_kill(str(killer.name) if is_instance_valid(killer) else "Arena", str(victim.name), weapon_title, headshot)
    if killer_team != victim_team and current_mode == "tdm": team_scores[killer_team] += 1
    if victim == local_player:
        hud.show_status("ELIMINATED", Color("ec7469"))
    if current_mode == "elimination":
        if get_living_allies(victim_team).is_empty(): _end_elimination_round()
    elif match_active:
        if current_mode == "tdm" and max(team_scores[0], team_scores[1]) >= 40:
            _finish_match()
        else:
            _respawn_after_delay(victim)

func _respawn_after_delay(actor) -> void:
    await get_tree().create_timer(3.0).timeout
    if not match_active or not is_instance_valid(actor): return
    actor.respawn(_spawn_for(int(actor.team), actors.filter(func(item): return int(item.team) == int(actor.team)).find(actor)))
    if actor == local_player: hud.show_status("")

func _end_elimination_round() -> void:
    if round_transition or not match_active: return
    round_transition = true
    var alive_alpha := get_living_allies(0).size()
    var alive_bravo := get_living_allies(1).size()
    if alive_alpha > alive_bravo: team_scores[0] += 1
    elif alive_bravo > alive_alpha: team_scores[1] += 1
    if max(team_scores[0], team_scores[1]) >= 5:
        _finish_match()
        return
    hud.show_status("ROUND %d COMPLETE" % round_number, Color("e8c969"))
    round_number += 1
    await get_tree().create_timer(3.0).timeout
    if not match_active: return
    for actor in actors:
        if is_instance_valid(actor):
            var team_members := actors.filter(func(item): return int(item.team) == int(actor.team))
            actor.respawn(_spawn_for(int(actor.team), team_members.find(actor)))
    match_time = 120.0
    round_transition = false
    hud.show_status("")

func _process_control(delta: float) -> void:
    control_tick += delta
    if control_tick < 1.0: return
    control_tick = 0.0
    var counts := [0, 0]
    var zone := get_objective_position()
    for actor in actors:
        if is_instance_valid(actor) and actor.alive:
            var flat_distance := Vector2(actor.global_position.x - zone.x, actor.global_position.z - zone.z).length()
            if flat_distance <= 5.3: counts[int(actor.team)] += 1
    if counts[0] > counts[1]:
        team_scores[0] += 1
        map_runtime.set_control_team(0)
    elif counts[1] > counts[0]:
        team_scores[1] += 1
        map_runtime.set_control_team(1)
    else:
        map_runtime.set_control_team(-1)
    if max(team_scores[0], team_scores[1]) >= 100: _finish_match()

func _finish_match() -> void:
    if not match_active: return
    match_active = false
    round_transition = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var victory := team_scores[0] >= team_scores[1]
    var title := "VICTORY" if victory else "DEFEAT"
    var detail := "%s • %s\nALPHA %d  —  %d BRAVO" % [MAP_LIBRARY.get_map(current_map)["name"], _mode_title(), team_scores[0], team_scores[1]]
    hud.set_match_visible(false)
    if is_instance_valid(touch_layer): touch_layer.visible = false
    lobby.show_result(title, detail, victory)

func _clear_match() -> void:
    match_active = false
    actors.clear()
    last_hits.clear()
    if is_instance_valid(map_runtime): map_runtime.queue_free()
    if is_instance_valid(actor_root): actor_root.queue_free()
    if is_instance_valid(touch_layer): touch_layer.queue_free()

func is_match_active() -> bool:
    return match_active and not round_transition

func get_living_opponents(team_id: int) -> Array:
    return actors.filter(func(actor): return is_instance_valid(actor) and actor.alive and int(actor.team) != team_id)

func get_living_allies(team_id: int) -> Array:
    return actors.filter(func(actor): return is_instance_valid(actor) and actor.alive and int(actor.team) == team_id)

func get_objective_position() -> Vector3:
    if is_instance_valid(map_runtime): return map_runtime.get_control_position()
    return Vector3.ZERO

func notify_shot(shooter, position: Vector3, loudness: float) -> void:
    for actor in actors:
        if actor != shooter and actor.has_method("hear_shot"):
            actor.hear_shot(position, int(shooter.team), loudness)

func can_damage(attacker, victim) -> bool:
    return is_instance_valid(attacker) and is_instance_valid(victim) and attacker != victim and int(attacker.team) != int(victim.team)

func register_hit(attacker, victim, headshot: bool) -> void:
    last_hits[victim.get_instance_id()] = {"attacker": attacker, "headshot": headshot}
    if attacker == local_player: hud.show_hit(headshot)

func update_weapon_hud(weapon_name: String, current_ammo: int, reserve: int) -> void:
    hud.update_weapon(weapon_name, current_ammo, reserve)

func show_damage_direction(_attacker_position: Vector3, _headshot: bool) -> void:
    hud.show_damage()

func _spawn_for(team_id: int, index: int) -> Vector3:
    return map_runtime.get_team_spawn(team_id, index)

func _objective_text() -> String:
    if current_mode == "tdm": return "FIRST TEAM TO 40 ELIMINATIONS"
    if current_mode == "elimination": return "ROUND %d  •  FIRST TO 5 ROUNDS" % round_number
    return "SECURE THE CONTROL ZONE  •  FIRST TO 100"

func _mode_title() -> String:
    match current_mode:
        "elimination": return "Elimination"
        "control": return "Control"
        _: return "Team Deathmatch"

func spawn_tracer(origin: Vector3, destination: Vector3, tracer_team: int, grenade_arc: bool = false) -> void:
    if not is_inside_tree(): return
    var length := origin.distance_to(destination)
    if length <= 0.02: return
    var tracer := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.018 if not grenade_arc else 0.07, 0.018 if not grenade_arc else 0.07, length)
    tracer.mesh = mesh
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color("56b8ff") if tracer_team == 0 else Color("ff765e")
    material.emission_enabled = true
    material.emission = material.albedo_color * 3.0
    tracer.material_override = material
    add_child(tracer)
    tracer.global_position = origin.lerp(destination, 0.5)
    tracer.look_at(destination, Vector3.UP)
    var tween := create_tween()
    tween.tween_property(tracer, "transparency", 1.0, 0.09 if not grenade_arc else 0.22)
    tween.tween_callback(tracer.queue_free)

func spawn_muzzle_flash(position: Vector3, _direction: Vector3) -> void:
    var flash := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.075
    sphere.height = 0.15
    flash.mesh = sphere
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color("ffd083")
    material.emission_enabled = true
    material.emission = Color("ff9f3f") * 4.0
    flash.material_override = material
    add_child(flash)
    flash.global_position = position
    var tween := create_tween()
    tween.tween_property(flash, "scale", Vector3.ONE * 0.15, 0.065)
    tween.tween_callback(flash.queue_free)

func explode(position: Vector3, damage: float, attacker) -> void:
    var blast := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.55
    sphere.height = 1.1
    blast.mesh = sphere
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(1.0, 0.34, 0.08, 0.74)
    material.emission_enabled = true
    material.emission = Color("ff681c") * 4.0
    blast.material_override = material
    add_child(blast)
    blast.global_position = position
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(blast, "scale", Vector3.ONE * 7.0, 0.3)
    tween.tween_property(blast, "transparency", 1.0, 0.34)
    tween.chain().tween_callback(blast.queue_free)
    for victim in actors:
        if not is_instance_valid(victim) or not victim.alive or not can_damage(attacker, victim): continue
        var distance := position.distance_to(victim.global_position + Vector3.UP)
        if distance > 7.0: continue
        var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 0.3, victim.global_position + Vector3.UP, 1)
        var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
        if not obstruction.is_empty() and obstruction.get("collider") != victim: continue
        var applied := damage * clampf(1.0 - distance / 8.0, 0.18, 1.0)
        register_hit(attacker, victim, false)
        victim.take_damage(applied, attacker, false)

func _ensure_input_actions() -> void:
    var actions := {
        "move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
        "jump": [KEY_SPACE], "reload": [KEY_R], "swap_weapon": [KEY_Q]
    }
    for action in actions:
        if not InputMap.has_action(action): InputMap.add_action(action)
        for keycode in actions[action]:
            var event := InputEventKey.new()
            event.physical_keycode = keycode
            InputMap.action_add_event(action, event)

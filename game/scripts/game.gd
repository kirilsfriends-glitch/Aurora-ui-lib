extends Node3D

const DOCKYARD_MAP := preload("res://scripts/dockyard_map.gd")
const PLAYER_CONTROLLER := preload("res://scripts/player_controller.gd")
const BOT_CONTROLLER := preload("res://scripts/bot_controller.gd")
const TOUCH_CONTROLS := preload("res://scripts/touch_fps_controls.gd")
const HUD := preload("res://scripts/hud.gd")
const LOBBY := preload("res://scripts/lobby.gd")

const SCORE_LIMIT := 30
const MATCH_DURATION := 360.0
const BOT_LOADOUTS_ALPHA := ["m4a1", "ak47", "glock", "awp"]
const BOT_LOADOUTS_BRAVO := ["ak47", "m4a1", "awp", "glock", "m4a1"]

var lobby
var hud
var touch_layer: CanvasLayer
var touch_controls
var map_runtime
var actor_root: Node3D
var local_player
var actors: Array = []
var current_mode := "tdm"
var difficulty := 0.7
var selected_loadout := "ak47"
var match_active := false
var match_time := MATCH_DURATION
var team_scores := [0, 0]
var last_hits: Dictionary = {}
var location_update := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    _ensure_input_actions()
    hud = HUD.new()
    add_child(hud)
    lobby = LOBBY.new()
    add_child(lobby)
    lobby.deployment_requested.connect(start_match)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func start_match(weapon_id: String, bot_difficulty: float) -> void:
    _clear_match()
    selected_loadout = weapon_id
    difficulty = bot_difficulty
    team_scores = [0, 0]
    match_time = MATCH_DURATION
    location_update = 0
    match_active = true

    map_runtime = DOCKYARD_MAP.new()
    add_child(map_runtime)
    map_runtime.build()
    actor_root = Node3D.new()
    actor_root.name = "Combatants"
    add_child(actor_root)
    _spawn_teams()
    _create_touch_controls()

    hud.set_match_visible(true)
    hud.clear_feed()
    hud.update_health(100)
    hud.update_objective("FIRST SQUAD TO %d ELIMINATIONS" % SCORE_LIMIT)
    hud.show_status("SQUADS DEPLOYED", Color("54d3d0"))
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    await get_tree().create_timer(1.25).timeout
    if match_active: hud.show_status("")

func _process(delta: float) -> void:
    if not match_active: return
    match_time = maxf(0.0, match_time - delta)
    location_update -= delta
    if location_update <= 0:
        location_update = 0.25
        if is_instance_valid(local_player):
            hud.update_location(map_runtime.get_location_name(local_player.global_position))
    hud.update_score(int(team_scores[0]), int(team_scores[1]), match_time, "Team Deathmatch")
    if match_time <= 0: _finish_match()

func _spawn_teams() -> void:
    local_player = PLAYER_CONTROLLER.new()
    actor_root.add_child(local_player)
    local_player.team = 0
    local_player.setup(self, _spawn_for(0, 0), selected_loadout)
    local_player.died.connect(_on_actor_died)
    local_player.health_changed.connect(hud.update_health)
    actors.append(local_player)

    for i in range(1, 5):
        _spawn_bot(0, i, BOT_LOADOUTS_ALPHA[i - 1])
    for i in range(5):
        _spawn_bot(1, i, BOT_LOADOUTS_BRAVO[i])

func _spawn_bot(team_id: int, index: int, loadout: String) -> void:
    var bot := BOT_CONTROLLER.new()
    actor_root.add_child(bot)
    var bot_skill := clampf(difficulty + rng.randf_range(-0.07, 0.07), 0.38, 0.94)
    bot.setup(self, team_id, index, _spawn_for(team_id, index), loadout, bot_skill)
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
    var victim_team: int = int(victim.team)
    var killer_team: int = int(killer.team) if is_instance_valid(killer) else 1 - victim_team
    var hit_info: Dictionary = last_hits.get(victim.get_instance_id(), {})
    var headshot: bool = bool(hit_info.get("headshot", false))
    var weapon_title := "ENVIRONMENT"
    if is_instance_valid(killer) and killer.get("weapon") != null:
        weapon_title = str(killer.weapon.config.get("name", "WEAPON"))
    hud.add_kill(_short_name(killer), _short_name(victim), weapon_title, headshot)

    if killer_team != victim_team:
        team_scores[killer_team] = int(team_scores[killer_team]) + 1
    if victim == local_player:
        hud.show_status("OPERATOR DOWN  •  REDEPLOYING", Color("f17b69"))
    if max(int(team_scores[0]), int(team_scores[1])) >= SCORE_LIMIT:
        _finish_match()
    else:
        _respawn_after_delay(victim)

func _respawn_after_delay(actor) -> void:
    await get_tree().create_timer(3.2).timeout
    if not match_active or not is_instance_valid(actor): return
    var team_members: Array = actors.filter(func(item): return int(item.team) == int(actor.team))
    actor.respawn(_spawn_for(int(actor.team), team_members.find(actor)))
    if actor == local_player: hud.show_status("")

func _finish_match() -> void:
    if not match_active: return
    match_active = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var victory: bool = int(team_scores[0]) >= int(team_scores[1])
    var title := "VICTORY" if victory else "DEFEAT"
    var detail := "DOCKYARD / NIGHT\nALPHA %02d   —   %02d BRAVO" % [team_scores[0], team_scores[1]]
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
    return match_active

func get_living_opponents(team_id: int) -> Array:
    return actors.filter(func(actor): return is_instance_valid(actor) and actor.alive and int(actor.team) != team_id)

func get_living_allies(team_id: int) -> Array:
    return actors.filter(func(actor): return is_instance_valid(actor) and actor.alive and int(actor.team) == team_id)

func get_objective_position() -> Vector3:
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

func _short_name(actor) -> String:
    if not is_instance_valid(actor): return "ARENA"
    if actor == local_player: return "YOU"
    return str(actor.name).replace(" Bot", "")

func spawn_tracer(origin: Vector3, destination: Vector3, tracer_team: int, grenade_arc: bool = false) -> void:
    var length := origin.distance_to(destination)
    if length <= 0.02: return
    var tracer := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.015 if not grenade_arc else 0.06, 0.015 if not grenade_arc else 0.06, length)
    tracer.mesh = mesh
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color("59d9e5") if tracer_team == 0 else Color("ff8566")
    material.emission_enabled = true
    material.emission = material.albedo_color * 3.2
    tracer.material_override = material
    add_child(tracer)
    tracer.global_position = origin.lerp(destination, 0.5)
    tracer.look_at(destination, Vector3.UP)
    var tween := create_tween()
    tween.tween_property(tracer, "transparency", 1.0, 0.075 if not grenade_arc else 0.2)
    tween.tween_callback(tracer.queue_free)

func spawn_muzzle_flash(position: Vector3, _direction: Vector3) -> void:
    var flash := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.065
    sphere.height = 0.13
    flash.mesh = sphere
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color("ffd098")
    material.emission_enabled = true
    material.emission = Color("ff983d") * 4.5
    flash.material_override = material
    add_child(flash)
    flash.global_position = position
    var tween := create_tween()
    tween.tween_property(flash, "scale", Vector3.ONE * 0.12, 0.055)
    tween.tween_callback(flash.queue_free)

func explode(position: Vector3, damage: float, attacker) -> void:
    var blast := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.5
    sphere.height = 1.0
    blast.mesh = sphere
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(1.0, 0.32, 0.06, 0.7)
    material.emission_enabled = true
    material.emission = Color("ff641c") * 4.0
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
        var distance: float = position.distance_to(victim.global_position + Vector3.UP)
        if distance > 7.0: continue
        var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 0.3, victim.global_position + Vector3.UP, 1)
        if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
        register_hit(attacker, victim, false)
        victim.take_damage(damage * clampf(1.0 - distance / 8.0, 0.18, 1.0), attacker, false)

func _ensure_input_actions() -> void:
    var actions := {
        "move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
        "jump": [KEY_SPACE], "reload": [KEY_R], "swap_weapon": [KEY_Q], "crouch": [KEY_C],
    }
    for action in actions:
        if not InputMap.has_action(action): InputMap.add_action(action)
        for keycode in actions[action]:
            var event := InputEventKey.new()
            event.physical_keycode = keycode
            InputMap.action_add_event(action, event)

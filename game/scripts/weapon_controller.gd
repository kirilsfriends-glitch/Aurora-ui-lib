extends Node3D

signal stats_changed(weapon_name: String, ammo: int, reserve: int)
signal recoil_requested(amount: float)

const WEAPON_DB := preload("res://scripts/weapon_database.gd")
const FIRE_AUDIO := {
    "ak47": "res://audio/ak47_fire.wav",
    "m4a1": "res://audio/m4a1_fire.wav",
    "awp": "res://audio/awp_fire.wav",
    "glock": "res://audio/glock_fire.wav",
}

var actor: CharacterBody3D
var game
var weapon_id := "ak47"
var config: Dictionary
var ammo := 0
var reserve := 0
var cooldown := 0.0
var reload_remaining := 0.0
var reloading := false
var view_model := false
var visual: Node3D
var muzzle: Marker3D
var fire_audio
var reload_audio
var dry_audio
var kick := 0.0
var reload_pose := 0.0
var idle_time := 0.0

func setup(owner_actor: CharacterBody3D, game_node: Node, initial_weapon: String, first_person: bool) -> void:
    actor = owner_actor
    game = game_node
    view_model = first_person
    muzzle = Marker3D.new()
    muzzle.position = Vector3(0.0, 0.02, -0.95)
    add_child(muzzle)
    _build_audio_players()
    equip(initial_weapon, true)

func _process(delta: float) -> void:
    cooldown = maxf(0.0, cooldown - delta)
    idle_time += delta
    kick = move_toward(kick, 0.0, delta * 10.5)
    reload_pose = move_toward(reload_pose, 1.0 if reloading else 0.0, delta * 4.8)
    if view_model:
        rotation.x = -kick * 0.12 + sin(idle_time * 1.7) * 0.002
        rotation.z = reload_pose * 0.34 + sin(idle_time * 1.15) * 0.003
        position.y = -reload_pose * 0.18 + sin(idle_time * 1.9) * 0.003
    if reloading:
        reload_remaining -= delta
        if reload_remaining <= 0.0: _finish_reload()

func equip(new_weapon_id: String, refill_ammo: bool = false) -> void:
    if not WEAPON_DB.WEAPONS.has(new_weapon_id): return
    weapon_id = new_weapon_id
    config = WEAPON_DB.get_weapon(weapon_id)
    reloading = false
    reload_remaining = 0.0
    reload_pose = 0.0
    if refill_ammo or ammo <= 0:
        ammo = int(config["mag"])
        reserve = int(config["reserve"])
    _set_audio_streams()
    _rebuild_visual()
    _emit_stats()

func try_fire(origin: Vector3, direction: Vector3, ads: bool = false) -> bool:
    if cooldown > 0.0 or reloading or actor == null or not actor.get("alive"): return false
    if int(config["mag"]) >= 0 and ammo <= 0:
        _play(dry_audio, 1.0)
        cooldown = 0.22
        start_reload()
        return false

    cooldown = 60.0 / float(config["rpm"])
    if int(config["mag"]) >= 0: ammo -= 1
    if str(config["class"]) == "GRENADE":
        _fire_grenade(origin, direction)
    else:
        for pellet in int(config["pellets"]):
            _fire_ray(origin, direction, ads, pellet)

    _play(fire_audio, randf_range(0.97, 1.025))
    kick = minf(kick + (1.5 if weapon_id == "awp" else 0.72), 1.8)
    if view_model: recoil_requested.emit(float(config["recoil"]))
    if is_instance_valid(game):
        game.notify_shot(actor, origin, clampf(float(config["damage"]) / 55.0, 0.35, 1.0))
        game.spawn_muzzle_flash(muzzle.global_position if is_instance_valid(muzzle) else origin, direction)
    _emit_stats()
    return true

func _fire_ray(origin: Vector3, direction: Vector3, ads: bool, _pellet: int) -> void:
    var spread := float(config["spread"])
    if ads: spread *= 0.30
    if actor.velocity.length() > 3.0: spread *= 1.58
    var shot_direction := _spread_direction(direction.normalized(), spread)
    var end := origin + shot_direction * float(config["range"])
    var query := PhysicsRayQueryParameters3D.create(origin, end, 3)
    query.exclude = [actor.get_rid()]
    query.collide_with_areas = false
    var result := actor.get_world_3d().direct_space_state.intersect_ray(query)
    var hit_position := end
    if not result.is_empty():
        hit_position = result["position"]
        var collider = result["collider"]
        if collider != null and collider.has_method("take_damage") and game.can_damage(actor, collider):
            var damage := float(config["damage"])
            var distance := origin.distance_to(hit_position)
            if distance > float(config["range"]) * 0.62: damage *= 0.82
            var head_height: float = collider.global_position.y + 1.18
            var headshot := hit_position.y > head_height
            if headshot: damage *= 1.55
            game.register_hit(actor, collider, headshot)
            collider.take_damage(damage, actor, headshot)
    if is_instance_valid(game): game.spawn_tracer(origin, hit_position, int(actor.team))

func _fire_grenade(origin: Vector3, direction: Vector3) -> void:
    var end := origin + direction.normalized() * float(config["range"])
    var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
    query.exclude = [actor.get_rid()]
    var result := actor.get_world_3d().direct_space_state.intersect_ray(query)
    var blast_position: Vector3 = result.get("position", end)
    if is_instance_valid(game):
        game.spawn_tracer(origin, blast_position, int(actor.team), true)
        game.explode(blast_position, float(config["damage"]), actor)

func start_reload() -> void:
    if reloading or int(config["mag"]) < 0 or ammo >= int(config["mag"]) or reserve <= 0: return
    reloading = true
    reload_remaining = float(config["reload"])
    _play(reload_audio, 1.0)
    _emit_stats()

func _finish_reload() -> void:
    reloading = false
    var needed := int(config["mag"]) - ammo
    var loaded := mini(needed, reserve)
    ammo += loaded
    reserve -= loaded
    _emit_stats()

func refill() -> void:
    ammo = int(config["mag"])
    reserve = int(config["reserve"])
    reloading = false
    reload_pose = 0.0
    cooldown = 0.0
    _emit_stats()

func _build_audio_players() -> void:
    if view_model:
        fire_audio = AudioStreamPlayer.new()
        reload_audio = AudioStreamPlayer.new()
        dry_audio = AudioStreamPlayer.new()
    else:
        fire_audio = AudioStreamPlayer3D.new()
        reload_audio = AudioStreamPlayer3D.new()
        dry_audio = AudioStreamPlayer3D.new()
        fire_audio.max_distance = 48.0
        reload_audio.max_distance = 16.0
        dry_audio.max_distance = 8.0
    fire_audio.volume_db = -2.5 if view_model else -5.0
    reload_audio.volume_db = -7.0
    dry_audio.volume_db = -8.0
    add_child(fire_audio)
    add_child(reload_audio)
    add_child(dry_audio)

func _set_audio_streams() -> void:
    var fire_path: String = FIRE_AUDIO.get(weapon_id, "res://audio/glock_fire.wav")
    if ResourceLoader.exists(fire_path): fire_audio.stream = load(fire_path)
    var reload_path := "res://audio/pistol_reload.wav" if str(config["class"]) == "PISTOL" else "res://audio/rifle_reload.wav"
    if ResourceLoader.exists(reload_path): reload_audio.stream = load(reload_path)
    if ResourceLoader.exists("res://audio/dry_fire.wav"): dry_audio.stream = load("res://audio/dry_fire.wav")

func _play(player, pitch: float) -> void:
    if not is_instance_valid(player) or player.stream == null: return
    player.pitch_scale = pitch
    player.play()

func _spread_direction(direction: Vector3, spread: float) -> Vector3:
    var right := direction.cross(Vector3.UP)
    if right.length_squared() < 0.01: right = Vector3.RIGHT
    right = right.normalized()
    var up := right.cross(direction).normalized()
    return (direction + right * randf_range(-spread, spread) + up * randf_range(-spread, spread)).normalized()

func _rebuild_visual() -> void:
    if is_instance_valid(visual): visual.queue_free()
    var path := "res://models/%s.glb" % str(config["model"])
    if ResourceLoader.exists(path):
        visual = (load(path) as PackedScene).instantiate()
    else:
        visual = _fallback_weapon()
    visual.rotation_degrees.y = 180.0
    visual.scale = Vector3.ONE * (0.72 if view_model else 0.55)
    add_child(visual)

func _fallback_weapon() -> Node3D:
    var root := Node3D.new()
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.16, 0.16, 1.3)
    instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("25364b")
    material.metallic = 0.8
    material.roughness = 0.25
    instance.material_override = material
    root.add_child(instance)
    return root

func _emit_stats() -> void:
    if config.is_empty(): return
    var suffix := "  RELOADING" if reloading else ""
    stats_changed.emit(str(config["name"]) + suffix, ammo, reserve)

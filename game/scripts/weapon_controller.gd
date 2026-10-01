extends Node3D

signal stats_changed(weapon_name: String, ammo: int, reserve: int)
signal recoil_requested(amount: float)

const WEAPON_DB := preload("res://scripts/weapon_database.gd")

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

func setup(owner_actor: CharacterBody3D, game_node: Node, initial_weapon: String, first_person: bool) -> void:
    actor = owner_actor
    game = game_node
    view_model = first_person
    muzzle = Marker3D.new()
    muzzle.position = Vector3(0.0, 0.02, -0.95)
    add_child(muzzle)
    equip(initial_weapon, true)

func _process(delta: float) -> void:
    cooldown = maxf(0.0, cooldown - delta)
    if reloading:
        reload_remaining -= delta
        if reload_remaining <= 0.0:
            _finish_reload()

func equip(new_weapon_id: String, refill: bool = false) -> void:
    if not WEAPON_DB.WEAPONS.has(new_weapon_id): return
    weapon_id = new_weapon_id
    config = WEAPON_DB.get_weapon(weapon_id)
    reloading = false
    reload_remaining = 0.0
    if refill or ammo <= 0:
        ammo = int(config["mag"])
        reserve = int(config["reserve"])
    _rebuild_visual()
    _emit_stats()

func try_fire(origin: Vector3, direction: Vector3, ads: bool = false) -> bool:
    if cooldown > 0.0 or reloading or actor == null or not actor.get("alive"): return false
    if int(config["mag"]) >= 0 and ammo <= 0:
        start_reload()
        return false
    cooldown = 60.0 / float(config["rpm"])
    if int(config["mag"]) >= 0: ammo -= 1
    var weapon_class: String = config["class"]
    if weapon_class == "GRENADE":
        _fire_grenade(origin, direction)
    else:
        var pellets := int(config["pellets"])
        for pellet in pellets:
            _fire_ray(origin, direction, ads, pellet)
    if view_model:
        recoil_requested.emit(float(config["recoil"]))
    if is_instance_valid(game):
        game.notify_shot(actor, origin, clampf(float(config["damage"]) / 55.0, 0.35, 1.0))
        game.spawn_muzzle_flash(muzzle.global_position if is_instance_valid(muzzle) else origin, direction)
    _animate_kick()
    _emit_stats()
    return true

func _fire_ray(origin: Vector3, direction: Vector3, ads: bool, pellet: int) -> void:
    var spread := float(config["spread"])
    if ads: spread *= 0.32
    if actor.velocity.length() > 3.0: spread *= 1.65
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
        if collider != null and collider.has_method("take_damage"):
                if not is_instance_valid(game) or game.can_damage(actor, collider):
                    var damage := float(config["damage"])
                    var distance := origin.distance_to(hit_position)
                    if distance > float(config["range"]) * 0.62: damage *= 0.82
                    var head_height := collider.global_position.y + 1.18
                    var headshot := hit_position.y > head_height
                    if headshot: damage *= 1.55
                    if is_instance_valid(game): game.register_hit(actor, collider, headshot)
                    collider.take_damage(damage, actor, headshot)
    if is_instance_valid(game): game.spawn_tracer(origin, hit_position, int(actor.get("team")))

func _fire_grenade(origin: Vector3, direction: Vector3) -> void:
    var end := origin + direction.normalized() * float(config["range"])
    var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
    query.exclude = [actor.get_rid()]
    var result := actor.get_world_3d().direct_space_state.intersect_ray(query)
    var blast_position: Vector3 = result.get("position", end)
    if is_instance_valid(game):
        game.spawn_tracer(origin, blast_position, int(actor.get("team")), true)
        game.explode(blast_position, float(config["damage"]), actor)

func start_reload() -> void:
    if reloading or int(config["mag"]) < 0 or ammo >= int(config["mag"]) or reserve <= 0: return
    reloading = true
    reload_remaining = float(config["reload"])
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
    cooldown = 0.0
    _emit_stats()

func _spread_direction(direction: Vector3, spread: float) -> Vector3:
    var right := direction.cross(Vector3.UP)
    if right.length_squared() < 0.01: right = Vector3.RIGHT
    right = right.normalized()
    var up := right.cross(direction).normalized()
    return (direction + right * randf_range(-spread, spread) + up * randf_range(-spread, spread)).normalized()

func _rebuild_visual() -> void:
    if is_instance_valid(visual): visual.queue_free()
    var path := "res://models/%s.glb" % String(config["model"])
    if ResourceLoader.exists(path):
        visual = (load(path) as PackedScene).instantiate()
    else:
        visual = _fallback_weapon()
    visual.rotation_degrees.y = 180.0
    visual.scale = Vector3.ONE * (0.72 if view_model else 0.55)
    add_child(visual)

func _fallback_weapon() -> Node3D:
    var root := Node3D.new()
    var mesh_instance := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.16, 0.16, 1.3)
    mesh_instance.mesh = box
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("25364b")
    material.metallic = 0.8
    material.roughness = 0.25
    mesh_instance.material_override = material
    root.add_child(mesh_instance)
    return root

func _animate_kick() -> void:
    rotation.x = -0.12
    var tween := create_tween()
    tween.tween_property(self, "rotation:x", 0.0, 0.1)

func _emit_stats() -> void:
    if config.is_empty(): return
    var suffix := "  RELOADING" if reloading else ""
    stats_changed.emit(String(config["name"]) + suffix, ammo, reserve)

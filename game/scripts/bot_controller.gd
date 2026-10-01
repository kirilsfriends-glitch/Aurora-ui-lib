extends CharacterBody3D

signal died(victim: Node, killer: Node)
signal health_changed(value: int)

const WEAPON_CONTROLLER := preload("res://scripts/weapon_controller.gd")
const WEAPON_DB := preload("res://scripts/weapon_database.gd")

enum State { PATROL, INVESTIGATE, COMBAT, COVER, RETREAT, OBJECTIVE }

var game
var team := 1
var bot_index := 0
var skill := 0.7
var alive := true
var health := 100.0
var state := State.PATROL
var target
var last_known_position := Vector3.ZERO
var move_goal := Vector3.ZERO
var path: PackedVector3Array = PackedVector3Array()
var path_index := 0
var weapon
var gun_mount: Node3D
var visual: Node3D
var think_timer := 0.0
var reaction_timer := 0.0
var patrol_timer := 0.0
var strafe_sign := 1.0
var crouching := false
var spawn_position := Vector3.ZERO
var invulnerable := 0.0
var recent_attacker: Node
var heard_position := Vector3.ZERO
var heard_timer := 0.0
var rng := RandomNumberGenerator.new()

func setup(game_node: Node, assigned_team: int, index: int, spawn: Vector3, loadout: String, bot_skill: float) -> void:
    game = game_node
    team = assigned_team
    bot_index = index
    skill = clampf(bot_skill, 0.35, 0.98)
    rng.seed = 1739 + index * 7919 + team * 103
    spawn_position = spawn
    global_position = spawn
    _build_body()
    weapon = WEAPON_CONTROLLER.new()
    gun_mount.add_child(weapon)
    weapon.setup(self, game, loadout, false)
    name = ("Alpha" if team == 0 else "Bravo") + " Bot %d" % (index + 1)
    collision_layer = 2
    collision_mask = 3
    floor_snap_length = 0.3
    move_goal = spawn
    invulnerable = 1.0

func _build_body() -> void:
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.36
    capsule.height = 1.72
    collision.shape = capsule
    collision.position.y = 0.86
    add_child(collision)

    if ResourceLoader.exists("res://models/tactical_operator.glb"):
        visual = (load("res://models/tactical_operator.glb") as PackedScene).instantiate()
        visual.scale = Vector3.ONE * 0.88
    else:
        var fallback := MeshInstance3D.new()
        var fallback_mesh := CapsuleMesh.new()
        fallback_mesh.radius = 0.38
        fallback_mesh.height = 1.7
        fallback.mesh = fallback_mesh
        fallback.position.y = 0.85
        var material := StandardMaterial3D.new()
        material.albedo_color = Color("4677a8") if team == 0 else Color("a94c45")
        material.metallic = 0.15
        material.roughness = 0.7
        fallback.material_override = material
        visual = fallback
    add_child(visual)

    var marker := MeshInstance3D.new()
    var marker_mesh := BoxMesh.new()
    marker_mesh.size = Vector3(0.78, 0.10, 0.16)
    marker.mesh = marker_mesh
    marker.position = Vector3(0, 1.45, 0.04)
    var marker_material := StandardMaterial3D.new()
    marker_material.albedo_color = Color("2b8de5") if team == 0 else Color("e34b44")
    marker_material.emission_enabled = true
    marker_material.emission = marker_material.albedo_color * 0.25
    marker.material_override = marker_material
    add_child(marker)

    gun_mount = Node3D.new()
    gun_mount.position = Vector3(0.28, 1.28, -0.38)
    add_child(gun_mount)

func _physics_process(delta: float) -> void:
    if not alive or game == null or not game.is_match_active(): return
    invulnerable = maxf(0.0, invulnerable - delta)
    think_timer -= delta
    reaction_timer = maxf(0.0, reaction_timer - delta)
    heard_timer = maxf(0.0, heard_timer - delta)
    patrol_timer -= delta
    if think_timer <= 0:
        think_timer = lerpf(0.34, 0.13, skill) + rng.randf_range(-0.025, 0.025)
        _think()
    _move(delta)
    _fight(delta)

func _think() -> void:
    var seen := _find_visible_enemy()
    if seen != null:
        if seen != target:
            reaction_timer = lerpf(0.72, 0.16, skill) + rng.randf_range(0.0, 0.14)
        target = seen
        last_known_position = target.global_position
        if health < 28 or weapon.reloading:
            state = State.RETREAT
            _select_cover(last_known_position)
        else:
            state = State.COMBAT
    elif is_instance_valid(target) and target.alive:
        last_known_position = target.global_position if _has_line_of_sight(target) else last_known_position
        state = State.INVESTIGATE
        _set_move_goal(last_known_position)
        target = null
    elif heard_timer > 0:
        state = State.INVESTIGATE
        _set_move_goal(heard_position)
    elif game.current_mode == "control":
        state = State.OBJECTIVE
        var zone_position: Vector3 = game.get_objective_position()
        if global_position.distance_to(zone_position) > 6.0:
            _set_move_goal(zone_position + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)))
    elif patrol_timer <= 0 or global_position.distance_to(move_goal) < 1.5:
        state = State.PATROL
        patrol_timer = rng.randf_range(3.0, 6.0)
        _set_move_goal(game.map_runtime.get_random_waypoint())

    if weapon.ammo <= 0 and not weapon.reloading:
        weapon.start_reload()
        if is_instance_valid(target):
            state = State.COVER
            _select_cover(target.global_position)

func _find_visible_enemy() -> Node3D:
    var best: Node3D
    var best_score := INF
    var forward := -global_basis.z
    for actor in game.get_living_opponents(team):
        var offset: Vector3 = actor.global_position - global_position
        var distance := offset.length()
        if distance > 45.0: continue
        var angle := rad_to_deg(acos(clampf(forward.dot(offset.normalized()), -1, 1)))
        if angle > (62.0 if target == null else 92.0): continue
        if not _has_line_of_sight(actor): continue
        var score := distance + angle * 0.09
        if actor == recent_attacker: score -= 8.0
        if score < best_score:
            best_score = score
            best = actor
    return best

func _has_line_of_sight(actor: Node3D) -> bool:
    if not is_instance_valid(actor): return false
    var origin := global_position + Vector3.UP * 1.42
    var destination := actor.global_position + Vector3.UP * 1.22
    var query := PhysicsRayQueryParameters3D.create(origin, destination, 3, [get_rid()])
    query.collide_with_areas = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    return hit.is_empty() or hit.get("collider") == actor

func _select_cover(danger_position: Vector3) -> void:
    var cover_points: Array[Vector3] = game.map_runtime.get_cover_points()
    var best := global_position
    var best_score := INF
    for point in cover_points:
        var distance := global_position.distance_to(point)
        if distance > 17.0: continue
        var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, danger_position + Vector3.UP, 1)
        var blocked := not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
        if not blocked: continue
        var score := distance + rng.randf_range(0, 3)
        if score < best_score:
            best_score = score
            best = point
    _set_move_goal(best)

func _set_move_goal(destination: Vector3) -> void:
    if move_goal.distance_to(destination) < 1.5 and not path.is_empty(): return
    move_goal = destination
    path = game.map_runtime.get_path(global_position, destination)
    path_index = 0

func _move(delta: float) -> void:
    var desired := Vector3.ZERO
    if state == State.COMBAT and is_instance_valid(target):
        var to_target := target.global_position - global_position
        var distance := to_target.length()
        if distance > _preferred_range(): desired += to_target.normalized()
        elif distance < _preferred_range() * 0.45: desired -= to_target.normalized()
        desired += global_basis.x * strafe_sign * 0.58
        if rng.randf() < 0.008: strafe_sign *= -1
    elif path_index < path.size():
        var waypoint: Vector3 = path[path_index]
        var flat_offset := waypoint - global_position
        flat_offset.y = 0
        if flat_offset.length() < 1.05:
            path_index += 1
        else:
            desired = flat_offset.normalized()
    else:
        var direct := move_goal - global_position
        direct.y = 0
        if direct.length() > 0.8: desired = direct.normalized()

    for ally in game.get_living_allies(team):
        if ally == self: continue
        var away := global_position - ally.global_position
        away.y = 0
        if away.length_squared() < 2.0 and away.length_squared() > 0.01:
            desired += away.normalized() * 0.55
    desired = desired.normalized()
    var speed := 5.5 * float(weapon.config["move"])
    if state == State.COMBAT: speed *= 0.78
    velocity.x = move_toward(velocity.x, desired.x * speed, 18.0 * delta)
    velocity.z = move_toward(velocity.z, desired.z * speed, 18.0 * delta)
    velocity.y = -0.5 if is_on_floor() else velocity.y - 23.0 * delta
    move_and_slide()
    if desired.length_squared() > 0.05:
        var target_yaw := atan2(-desired.x, -desired.z)
        if state == State.COMBAT and is_instance_valid(target):
            var aim_offset := target.global_position - global_position
            target_yaw = atan2(-aim_offset.x, -aim_offset.z)
        rotation.y = lerp_angle(rotation.y, target_yaw, delta * 9.0)
    if is_instance_valid(visual):
        visual.rotation.z = lerpf(visual.rotation.z, -velocity.x * 0.007, 7.0 * delta)

func _fight(_delta: float) -> void:
    if state != State.COMBAT or not is_instance_valid(target) or reaction_timer > 0 or weapon.reloading: return
    if not target.alive or not _has_line_of_sight(target): return
    var origin := global_position + Vector3.UP * 1.34 + (-global_basis.z * 0.32)
    var target_point := target.global_position + Vector3.UP * (1.47 if rng.randf() < skill * 0.32 else 1.08)
    var distance := origin.distance_to(target_point)
    var inaccuracy := lerpf(0.105, 0.012, skill) * (1.0 + distance / 42.0)
    var direction := (target_point - origin).normalized()
    direction = (direction + global_basis.x * rng.randfn(0, inaccuracy) + Vector3.UP * rng.randfn(0, inaccuracy)).normalized()
    if _friendly_in_firing_line(origin, origin + direction * minf(distance + 2, 50)): return
    weapon.try_fire(origin, direction, distance > 12.0)

func _friendly_in_firing_line(origin: Vector3, destination: Vector3) -> bool:
    var query := PhysicsRayQueryParameters3D.create(origin, destination, 2, [get_rid()])
    var result := get_world_3d().direct_space_state.intersect_ray(query)
    if result.is_empty(): return false
    var actor = result.get("collider")
    return actor != null and actor.has_method("take_damage") and int(actor.team) == team

func _preferred_range() -> float:
    var kind := str(weapon.config["class"]).to_lower()
    if kind == "sniper": return 24.0
    if kind == "smg" or kind == "shotgun": return 9.0
    return 15.0

func hear_shot(position: Vector3, shot_team: int, loudness: float) -> void:
    if not alive or shot_team == team: return
    var range := 9.0 + loudness * 21.0
    if global_position.distance_to(position) <= range:
        heard_position = position + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
        heard_timer = 4.5

func take_damage(amount: float, attacker, _headshot: bool = false) -> void:
    if not alive or invulnerable > 0: return
    health -= amount
    recent_attacker = attacker
    if is_instance_valid(attacker):
        target = attacker
        reaction_timer = minf(reaction_timer, 0.12)
    health_changed.emit(maxi(0, int(ceil(health))))
    if health <= 0:
        alive = false
        died.emit(self, attacker)
        visible = false
        var shape := _collision_shape()
        if shape: shape.set_deferred("disabled", true)

func respawn(position: Vector3) -> void:
    global_position = position
    spawn_position = position
    velocity = Vector3.ZERO
    health = 100
    alive = true
    visible = true
    target = null
    state = State.PATROL
    invulnerable = 1.0
    if is_instance_valid(weapon): weapon.refill()
    var shape := _collision_shape()
    if shape: shape.set_deferred("disabled", false)
    health_changed.emit(100)

func _collision_shape() -> CollisionShape3D:
    for child in get_children():
        if child is CollisionShape3D: return child
    return null

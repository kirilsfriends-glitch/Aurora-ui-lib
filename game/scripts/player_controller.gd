extends CharacterBody3D

signal died(victim: Node, killer: Node)
signal health_changed(value: int)

const WEAPON_CONTROLLER := preload("res://scripts/weapon_controller.gd")
const WEAPON_DB := preload("res://scripts/weapon_database.gd")

var game
var team := 0
var alive := true
var health := 100.0
var camera: Camera3D
var view_pivot: Node3D
var weapon_mount: Node3D
var weapon
var touch_move := Vector2.ZERO
var fire_held := false
var fire_just_pressed := false
var ads_held := false
var jump_buffer := 0.0
var crouching := false
var touch_crouch := false
var look_sway := Vector2.ZERO
var yaw := 0.0
var pitch := 0.0
var mouse_sensitivity := 0.0022
var touch_sensitivity := 0.0035
var weapon_index := 0
var spawn_position := Vector3.ZERO
var invulnerable := 0.0
var bob_time := 0.0

func _ready() -> void:
    name = "LocalPlayer"
    collision_layer = 2
    collision_mask = 3
    floor_snap_length = 0.25
    _build_body()

func setup(game_node: Node, spawn: Vector3, initial_weapon: String = "ak47") -> void:
    game = game_node
    spawn_position = spawn
    global_position = spawn
    weapon_index = maxi(0, WEAPON_DB.ACTIVE_ORDER.find(initial_weapon))
    weapon = WEAPON_CONTROLLER.new()
    weapon_mount.add_child(weapon)
    weapon.setup(self, game, initial_weapon, true)
    weapon.stats_changed.connect(_on_weapon_stats)
    weapon.recoil_requested.connect(_on_recoil)
    respawn(spawn)

func _build_body() -> void:
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.34
    shape.height = 1.72
    collision.shape = shape
    collision.position.y = 0.86
    add_child(collision)

    var body_visual: Node3D
    if ResourceLoader.exists("res://models/tactical_operator.glb"):
        body_visual = (load("res://models/tactical_operator.glb") as PackedScene).instantiate()
        body_visual.scale = Vector3.ONE * 0.88
    else:
        var mesh_instance := MeshInstance3D.new()
        var capsule := CapsuleMesh.new()
        capsule.radius = 0.38
        capsule.height = 1.7
        mesh_instance.mesh = capsule
        mesh_instance.position.y = 0.85
        body_visual = mesh_instance
    body_visual.name = "WorldBody"
    add_child(body_visual)
    _set_render_layer(body_visual, 2)

    view_pivot = Node3D.new()
    view_pivot.position.y = 1.55
    add_child(view_pivot)
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 72.0
    camera.near = 0.05
    camera.cull_mask = 0xFFFFF & ~2
    view_pivot.add_child(camera)
    weapon_mount = Node3D.new()
    weapon_mount.position = Vector3(0.32, -0.27, -0.62)
    camera.add_child(weapon_mount)

func _unhandled_input(event: InputEvent) -> void:
    if not alive or game == null or not game.is_match_active(): return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        apply_look(event.relative, mouse_sensitivity)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        fire_just_pressed = true
    if event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
    invulnerable = maxf(0.0, invulnerable - delta)
    if not alive or game == null or not game.is_match_active(): return
    var using_ads := ads_held or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
    var target_fov := 72.0
    if using_ads:
        target_fov = 28.0 if int(weapon.config["scope"]) > 0 else 52.0
    camera.fov = lerpf(camera.fov, target_fov, 10.0 * delta)
    var target_mount := Vector3(0.02, -0.22, -0.56) if using_ads else Vector3(0.32, -0.27, -0.62)
    var sway_scale := 0.00035 if using_ads else 0.00075
    target_mount += Vector3(-look_sway.x * sway_scale, look_sway.y * sway_scale, 0)
    weapon_mount.position = weapon_mount.position.lerp(target_mount, 10.0 * delta)
    weapon_mount.rotation.z = lerpf(weapon_mount.rotation.z, -look_sway.x * 0.00018, 9.0 * delta)
    look_sway = look_sway.lerp(Vector2.ZERO, 8.0 * delta)

func _physics_process(delta: float) -> void:
    if not alive or game == null or not game.is_match_active(): return
    jump_buffer = maxf(0.0, jump_buffer - delta)
    crouching = touch_crouch or Input.is_action_pressed("crouch")
    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if touch_move.length_squared() > 0.01: input_vector = touch_move
    var forward := -global_basis.z
    var right := global_basis.x
    var direction := (right * input_vector.x + forward * -input_vector.y)
    direction.y = 0
    direction = direction.normalized()
    var speed := 6.6 * float(weapon.config["move"])
    var using_ads := ads_held or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
    if using_ads: speed *= 0.72
    if crouching: speed *= 0.58
    var acceleration := 24.0 if is_on_floor() else 8.0
    velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
    velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
    if is_on_floor():
        velocity.y = -0.6
        if jump_buffer > 0:
            velocity.y = 8.2
            jump_buffer = 0
    else:
        velocity.y -= 23.0 * delta
    move_and_slide()
    _animate_camera(delta, direction.length() * Vector2(velocity.x, velocity.z).length())

    var keyboard_fire := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
    var wants_fire := fire_held or keyboard_fire
    var automatic := bool(weapon.config["auto"])
    if (automatic and wants_fire) or fire_just_pressed:
        weapon.try_fire(camera.global_position, -camera.global_basis.z, using_ads)
    fire_just_pressed = false
    if Input.is_action_just_pressed("reload"): weapon.start_reload()
    if Input.is_action_just_pressed("jump"): request_jump()
    if Input.is_action_just_pressed("swap_weapon"): next_weapon()

func apply_look(relative: Vector2, sensitivity: float = -1.0) -> void:
    var value := touch_sensitivity if sensitivity < 0 else sensitivity
    yaw -= relative.x * value
    pitch = clampf(pitch - relative.y * value, deg_to_rad(-82), deg_to_rad(82))
    rotation.y = yaw
    view_pivot.rotation.x = pitch
    look_sway += relative.limit_length(80.0)

func set_touch_move(value: Vector2) -> void: touch_move = value
func set_fire(value: bool) -> void:
    if value and not fire_held: fire_just_pressed = true
    fire_held = value
func set_ads(value: bool) -> void: ads_held = value
func set_crouch(value: bool) -> void: touch_crouch = value
func request_jump() -> void: jump_buffer = 0.18
func request_reload() -> void:
    if is_instance_valid(weapon): weapon.start_reload()

func next_weapon() -> void:
    if not alive: return
    weapon_index = (weapon_index + 1) % WEAPON_DB.ACTIVE_ORDER.size()
    weapon.equip(WEAPON_DB.ACTIVE_ORDER[weapon_index], true)

func take_damage(amount: float, attacker, headshot: bool = false) -> void:
    if not alive or invulnerable > 0 or attacker == self: return
    health -= amount
    health_changed.emit(maxi(0, int(ceil(health))))
    if game != null: game.show_damage_direction(attacker.global_position, headshot)
    if health <= 0:
        alive = false
        fire_held = false
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
    invulnerable = 1.5
    var shape := _collision_shape()
    if shape: shape.set_deferred("disabled", false)
    if is_instance_valid(weapon): weapon.refill()
    health_changed.emit(100)

func _collision_shape() -> CollisionShape3D:
    for child in get_children():
        if child is CollisionShape3D: return child
    return null

func _animate_camera(delta: float, movement_speed: float) -> void:
    bob_time += delta * movement_speed
    var target_height := 1.12 if crouching else 1.55
    view_pivot.position.y = lerpf(view_pivot.position.y, target_height + sin(bob_time * 1.7) * minf(movement_speed * 0.005, 0.035), 10 * delta)

func _on_weapon_stats(weapon_name: String, current_ammo: int, current_reserve: int) -> void:
    if game != null: game.update_weapon_hud(weapon_name, current_ammo, current_reserve)

func _on_recoil(amount: float) -> void:
    pitch = clampf(pitch + deg_to_rad(amount), deg_to_rad(-82), deg_to_rad(82))
    view_pivot.rotation.x = pitch

func _set_render_layer(node: Node, layer: int) -> void:
    if node is GeometryInstance3D: node.layers = layer
    for child in node.get_children(): _set_render_layer(child, layer)

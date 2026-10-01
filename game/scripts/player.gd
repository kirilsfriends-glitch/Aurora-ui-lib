extends CharacterBody3D

signal fell_into_void

const DRONE_SCENE := preload("res://models/aurora_drone.glb")
const MOVE_SPEED := 7.4
const GROUND_ACCELERATION := 24.0
const AIR_ACCELERATION := 9.0
const DEFAULT_JUMP := 10.5
const BASE_GRAVITY := 27.0

var orbit_camera: Camera3D
var visual_root: Node3D
var touch_vector := Vector2.ZERO
var jump_buffer := 0.0
var gravity_multiplier := 1.0
var controls_enabled := true
var spawn_position := Vector3.ZERO
var bob_time := 0.0


func _ready() -> void:
    name = "AuroraDrone"
    floor_snap_length = 0.28
    floor_max_angle = deg_to_rad(52.0)

    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.48
    shape.height = 1.2
    collision.shape = shape
    add_child(collision)

    visual_root = Node3D.new()
    visual_root.name = "BlenderDroneVisual"
    add_child(visual_root)

    var model := DRONE_SCENE.instantiate()
    model.name = "AuroraDroneModel"
    model.scale = Vector3.ONE * 0.62
    model.rotation_degrees.y = 180.0
    model.position.y = -0.02
    visual_root.add_child(model)

    # The Blender thrusters are emissive; a per-frame OmniLight was redundant
    # and expensive on tiled mobile GPUs.


func _process(delta: float) -> void:
    bob_time += delta
    if is_instance_valid(visual_root):
        visual_root.position.y = sin(bob_time * 5.5) * 0.045
        visual_root.rotation.z = lerpf(visual_root.rotation.z, -velocity.x * 0.018, 6.0 * delta)


func _physics_process(delta: float) -> void:
    jump_buffer = maxf(0.0, jump_buffer - delta)

    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if touch_vector.length_squared() > 0.01:
        input_vector = touch_vector.limit_length(1.0)
    if not controls_enabled:
        input_vector = Vector2.ZERO

    var forward := Vector3.FORWARD
    var right := Vector3.RIGHT
    if is_instance_valid(orbit_camera):
        forward = -orbit_camera.global_basis.z
        forward.y = 0.0
        forward = forward.normalized()
        right = orbit_camera.global_basis.x
        right.y = 0.0
        right = right.normalized()

    var move_direction := (right * input_vector.x + forward * -input_vector.y).normalized()
    var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
    var target := move_direction * MOVE_SPEED
    velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
    velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

    if is_on_floor():
        if controls_enabled and (Input.is_action_just_pressed("jump") or jump_buffer > 0.0):
            velocity.y = DEFAULT_JUMP
            jump_buffer = 0.0
        else:
            velocity.y = -0.8
    else:
        velocity.y -= BASE_GRAVITY * gravity_multiplier * delta

    if move_direction.length_squared() > 0.01 and is_instance_valid(visual_root):
        var target_yaw := atan2(-move_direction.x, -move_direction.z)
        visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, 9.0 * delta)

    move_and_slide()

    if global_position.y < -10.0:
        fell_into_void.emit()


func set_camera(value: Camera3D) -> void:
    orbit_camera = value


func set_touch_input(value: Vector2) -> void:
    touch_vector = value


func request_jump() -> void:
    jump_buffer = 0.18


func launch(upward_force: float, forward_force: float = 0.0) -> void:
    velocity.y = upward_force
    if is_instance_valid(orbit_camera) and forward_force > 0.0:
        var direction := -orbit_camera.global_basis.z
        direction.y = 0.0
        velocity += direction.normalized() * forward_force


func reset_to(value: Vector3) -> void:
    global_position = value
    spawn_position = value
    velocity = Vector3.ZERO
    touch_vector = Vector2.ZERO


func set_controls_enabled(value: bool) -> void:
    controls_enabled = value
    if not value:
        touch_vector = Vector2.ZERO


func set_gravity_multiplier(value: float) -> void:
    gravity_multiplier = value

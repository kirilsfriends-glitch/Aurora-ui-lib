extends Camera3D

var target: Node3D
var yaw := 0.0
var pitch := deg_to_rad(36.0)
var distance := 12.5
var min_distance := 7.5
var max_distance := 17.0
var rotate_button_axis := 0.0
var mouse_dragging := false
var look_sensitivity := 0.006
var follow_speed := 7.0


func _ready() -> void:
    name = "OrbitCamera"
    current = true
    fov = 58.0
    near = 0.12


func _process(delta: float) -> void:
    if not is_instance_valid(target):
        return

    var keyboard_axis := Input.get_axis("camera_left", "camera_right")
    yaw += (keyboard_axis + rotate_button_axis) * 1.65 * delta

    var horizontal := cos(pitch) * distance
    var offset := Vector3(sin(yaw) * horizontal, sin(pitch) * distance, cos(yaw) * horizontal)
    var focus := target.global_position + Vector3(0.0, 0.75, 0.0)
    var desired := focus + offset
    var weight := 1.0 - exp(-follow_speed * delta)
    global_position = global_position.lerp(desired, weight)
    look_at(focus, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
            mouse_dragging = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom(-1.0)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom(1.0)
    elif event is InputEventMouseMotion and mouse_dragging:
        orbit(event.relative)
    elif event is InputEventScreenDrag:
        var width := get_viewport().get_visible_rect().size.x
        if event.position.x > width * 0.42:
            orbit(event.relative)


func orbit(relative: Vector2) -> void:
    yaw -= relative.x * look_sensitivity
    pitch = clampf(pitch - relative.y * look_sensitivity, deg_to_rad(20.0), deg_to_rad(68.0))


func zoom(amount: float) -> void:
    distance = clampf(distance + amount, min_distance, max_distance)


func set_target(value: Node3D, snap: bool = false) -> void:
    target = value
    if snap and is_instance_valid(target):
        var horizontal := cos(pitch) * distance
        global_position = target.global_position + Vector3(sin(yaw) * horizontal, sin(pitch) * distance, cos(yaw) * horizontal)
        look_at(target.global_position + Vector3(0.0, 0.75, 0.0), Vector3.UP)


func set_button_axis(value: float) -> void:
    rotate_button_axis = value


func reset_view(new_yaw: float = 0.0, new_pitch_degrees: float = 36.0, new_distance: float = 12.5) -> void:
    yaw = new_yaw
    pitch = deg_to_rad(new_pitch_degrees)
    distance = new_distance

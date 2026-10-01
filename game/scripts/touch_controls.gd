extends Control

signal movement_changed(value: Vector2)
signal jump_requested
signal camera_dragged(relative: Vector2)

const JOYSTICK_RADIUS := 86.0
const JOYSTICK_DEADZONE := 0.12
const JUMP_RADIUS := 72.0

var controls_enabled := false
var touch_roles: Dictionary = {}
var movement_touch := -1
var movement_origin := Vector2.ZERO
var movement_knob := Vector2.ZERO
var movement_value := Vector2.ZERO


func _ready() -> void:
    name = "MultiTouchControls"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    resized.connect(queue_redraw)
    queue_redraw()


func _input(event: InputEvent) -> void:
    if not controls_enabled or not visible:
        return

    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        _handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        if touch_roles.has(event.index):
            return
        if event.position.distance_to(_jump_center()) <= JUMP_RADIUS * 1.35:
            touch_roles[event.index] = "jump"
            jump_requested.emit()
            queue_redraw()
        elif event.position.x < size.x * 0.46 and event.position.y > 88.0 and movement_touch == -1:
            touch_roles[event.index] = "move"
            movement_touch = event.index
            movement_origin = _clamp_joystick_origin(event.position)
            movement_knob = movement_origin
            _update_movement(event.position)
        else:
            touch_roles[event.index] = "camera"
    else:
        var role: String = touch_roles.get(event.index, "")
        if role == "move":
            movement_touch = -1
            movement_value = Vector2.ZERO
            movement_changed.emit(Vector2.ZERO)
            movement_origin = _default_joystick_center()
            movement_knob = movement_origin
        touch_roles.erase(event.index)
        queue_redraw()


func _handle_drag(event: InputEventScreenDrag) -> void:
    var role: String = touch_roles.get(event.index, "")
    if role == "move":
        _update_movement(event.position)
    elif role == "camera":
        camera_dragged.emit(event.relative)


func _update_movement(position: Vector2) -> void:
    var raw := (position - movement_origin) / JOYSTICK_RADIUS
    var length := minf(raw.length(), 1.0)
    if length <= JOYSTICK_DEADZONE:
        movement_value = Vector2.ZERO
    else:
        var strength := (length - JOYSTICK_DEADZONE) / (1.0 - JOYSTICK_DEADZONE)
        movement_value = raw.normalized() * strength
    movement_knob = movement_origin + raw.limit_length(1.0) * JOYSTICK_RADIUS
    movement_changed.emit(movement_value)
    queue_redraw()


func set_controls_enabled(value: bool) -> void:
    controls_enabled = value
    visible = value
    if not value:
        reset_inputs()
    queue_redraw()


func reset_inputs() -> void:
    touch_roles.clear()
    movement_touch = -1
    movement_value = Vector2.ZERO
    movement_origin = _default_joystick_center()
    movement_knob = movement_origin
    movement_changed.emit(Vector2.ZERO)
    queue_redraw()


func _default_joystick_center() -> Vector2:
    return Vector2(132.0, maxf(132.0, size.y - 132.0))


func _clamp_joystick_origin(position: Vector2) -> Vector2:
    return Vector2(
        clampf(position.x, JOYSTICK_RADIUS + 22.0, size.x * 0.43 - JOYSTICK_RADIUS),
        clampf(position.y, 122.0 + JOYSTICK_RADIUS, size.y - JOYSTICK_RADIUS - 22.0)
    )


func _jump_center() -> Vector2:
    return Vector2(maxf(92.0, size.x - 112.0), maxf(112.0, size.y - 126.0))


func _draw() -> void:
    if not controls_enabled:
        return

    if movement_origin == Vector2.ZERO:
        movement_origin = _default_joystick_center()
        movement_knob = movement_origin

    var accent := Color(0.30, 0.96, 0.86, 0.78)
    var violet := Color(0.48, 0.36, 0.98, 0.78)
    draw_circle(movement_origin, JOYSTICK_RADIUS + 13.0, Color(0.02, 0.05, 0.16, 0.48))
    draw_circle(movement_origin, JOYSTICK_RADIUS, Color(0.12, 0.28, 0.48, 0.30))
    draw_arc(movement_origin, JOYSTICK_RADIUS, 0.0, TAU, 64, accent, 3.0, true)
    draw_circle(movement_knob, 35.0, Color(0.22, 0.75, 0.72, 0.72))
    draw_arc(movement_knob, 35.0, 0.0, TAU, 32, Color(0.72, 1.0, 0.95, 0.94), 3.0, true)

    var jump_center := _jump_center()
    draw_circle(jump_center, JUMP_RADIUS + 8.0, Color(0.02, 0.04, 0.14, 0.52))
    draw_circle(jump_center, JUMP_RADIUS, Color(0.32, 0.20, 0.72, 0.56))
    draw_arc(jump_center, JUMP_RADIUS, 0.0, TAU, 64, violet, 3.0, true)
    var font := ThemeDB.fallback_font
    var jump_size := font.get_string_size("JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 21)
    draw_string(font, jump_center - Vector2(jump_size.x * 0.5, -7.0), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)

    var hint := "DRAG TO LOOK"
    var hint_size := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
    draw_string(font, Vector2(size.x * 0.72 - hint_size.x * 0.5, size.y - 27.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.72, 0.82, 1.0, 0.62))

extends Control

signal movement_changed(value: Vector2)
signal look_dragged(relative: Vector2)
signal fire_changed(pressed: bool)
signal ads_changed(pressed: bool)
signal jump_requested
signal reload_requested
signal swap_requested
signal crouch_changed(pressed: bool)

const STICK_RADIUS := 82.0
const DEADZONE := 0.12

var controls_enabled := false
var roles: Dictionary = {}
var move_touch := -1
var move_origin := Vector2.ZERO
var move_knob := Vector2.ZERO
var movement := Vector2.ZERO
var fire_touches := 0
var ads_touches := 0

func _ready() -> void:
    name = "FPSMultiTouchControls"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    resized.connect(queue_redraw)

func setup(player: Node) -> void:
    movement_changed.connect(Callable(player, "set_touch_move"))
    look_dragged.connect(Callable(player, "apply_look"))
    fire_changed.connect(Callable(player, "set_fire"))
    ads_changed.connect(Callable(player, "set_ads"))
    jump_requested.connect(Callable(player, "request_jump"))
    reload_requested.connect(Callable(player, "request_reload"))
    swap_requested.connect(Callable(player, "next_weapon"))
    crouch_changed.connect(Callable(player, "set_crouch"))
    set_controls_enabled(true)

func _input(event: InputEvent) -> void:
    if not controls_enabled or not visible: return
    if event is InputEventScreenTouch: _touch(event)
    elif event is InputEventScreenDrag: _drag(event)

func _touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        if roles.has(event.index): return
        var role := _role_at(event.position)
        if role == "move" and move_touch != -1: role = "look"
        roles[event.index] = role
        match role:
            "move":
                move_touch = event.index
                move_origin = _clamp_stick(event.position)
                move_knob = move_origin
                _update_move(event.position)
            "fire":
                fire_touches += 1
                fire_changed.emit(true)
                Input.vibrate_handheld(12, 0.25)
            "ads":
                ads_touches += 1
                ads_changed.emit(true)
            "jump":
                jump_requested.emit()
                Input.vibrate_handheld(9, 0.18)
            "reload": reload_requested.emit()
            "swap": swap_requested.emit()
            "crouch": crouch_changed.emit(true)
    else:
        var role: String = roles.get(event.index, "")
        if role == "move":
            move_touch = -1
            movement = Vector2.ZERO
            movement_changed.emit(Vector2.ZERO)
            move_origin = _default_stick()
            move_knob = move_origin
        elif role == "fire":
            fire_touches = maxi(0, fire_touches - 1)
            if fire_touches == 0: fire_changed.emit(false)
        elif role == "ads":
            ads_touches = maxi(0, ads_touches - 1)
            if ads_touches == 0: ads_changed.emit(false)
        elif role == "crouch": crouch_changed.emit(false)
        roles.erase(event.index)
    queue_redraw()

func _drag(event: InputEventScreenDrag) -> void:
    var role: String = roles.get(event.index, "")
    if role == "move": _update_move(event.position)
    elif role == "look": look_dragged.emit(event.relative)

func _role_at(position: Vector2) -> String:
    if position.distance_to(_button_center("fire")) < 86: return "fire"
    if position.distance_to(_button_center("jump")) < 60: return "jump"
    if position.distance_to(_button_center("ads")) < 56: return "ads"
    if position.distance_to(_button_center("reload")) < 48: return "reload"
    if position.distance_to(_button_center("swap")) < 48: return "swap"
    if position.distance_to(_button_center("crouch")) < 46: return "crouch"
    if position.x < size.x * 0.44 and position.y > 90: return "move"
    return "look"

func _update_move(position: Vector2) -> void:
    var raw := (position - move_origin) / STICK_RADIUS
    var length := minf(raw.length(), 1.0)
    if length <= DEADZONE: movement = Vector2.ZERO
    else: movement = raw.normalized() * ((length - DEADZONE) / (1.0 - DEADZONE))
    move_knob = move_origin + raw.limit_length(1.0) * STICK_RADIUS
    movement_changed.emit(movement)
    queue_redraw()

func set_controls_enabled(value: bool) -> void:
    controls_enabled = value
    visible = value
    if not value: reset_inputs()
    queue_redraw()

func reset_inputs() -> void:
    roles.clear()
    move_touch = -1
    movement = Vector2.ZERO
    movement_changed.emit(Vector2.ZERO)
    fire_touches = 0
    ads_touches = 0
    fire_changed.emit(false)
    ads_changed.emit(false)
    move_origin = _default_stick()
    move_knob = move_origin

func _default_stick() -> Vector2:
    return Vector2(130, maxf(130, size.y - 132))

func _clamp_stick(position: Vector2) -> Vector2:
    return Vector2(clampf(position.x, 100, size.x * 0.42 - 90), clampf(position.y, 190, size.y - 95))

func _button_center(button: String) -> Vector2:
    match button:
        "fire": return Vector2(size.x - 112, size.y - 190)
        "jump": return Vector2(size.x - 245, size.y - 220)
        "ads": return Vector2(size.x - 245, size.y - 105)
        "reload": return Vector2(size.x - 108, size.y - 75)
        "swap": return Vector2(size.x - 370, size.y - 72)
        "crouch": return Vector2(size.x - 350, size.y - 190)
    return Vector2.ZERO

func _draw() -> void:
    if not controls_enabled: return
    if move_origin == Vector2.ZERO:
        move_origin = _default_stick()
        move_knob = move_origin
    var cyan := Color(0.28, 0.94, 0.86, 0.82)
    draw_circle(move_origin, STICK_RADIUS + 10, Color(0.01, 0.04, 0.1, 0.5))
    draw_circle(move_origin, STICK_RADIUS, Color(0.12, 0.34, 0.5, 0.32))
    draw_arc(move_origin, STICK_RADIUS, 0, TAU, 56, cyan, 3, true)
    draw_circle(move_knob, 34, Color(0.25, 0.78, 0.72, 0.78))
    draw_arc(move_knob, 34, 0, TAU, 32, Color.WHITE, 2, true)
    _draw_button("fire", 68, Color(1.0, 0.2, 0.35, 0.66), "FIRE", 20)
    _draw_button("jump", 47, Color(0.3, 0.38, 0.85, 0.64), "JUMP", 14)
    _draw_button("ads", 43, Color(0.18, 0.5, 0.68, 0.64), "ADS", 14)
    _draw_button("reload", 36, Color(0.22, 0.28, 0.45, 0.68), "R", 17)
    _draw_button("swap", 36, Color(0.22, 0.28, 0.45, 0.68), "SWAP", 11)
    _draw_button("crouch", 36, Color(0.22, 0.28, 0.45, 0.68), "DUCK", 11)

func _draw_button(id: String, radius: float, color: Color, text: String, font_size: int) -> void:
    var center := _button_center(id)
    draw_circle(center, radius + 6, Color(0.01, 0.03, 0.1, 0.5))
    draw_circle(center, radius, color)
    draw_arc(center, radius, 0, TAU, 40, color.lightened(0.32), 2.5, true)
    var font := ThemeDB.fallback_font
    var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    draw_string(font, center + Vector2(-text_size.x * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

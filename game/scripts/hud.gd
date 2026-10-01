extends CanvasLayer

var score_label: Label
var timer_label: Label
var mode_label: Label
var health_label: Label
var ammo_label: Label
var weapon_label: Label
var objective_label: Label
var status_label: Label
var kill_feed: VBoxContainer
var hit_marker: Control
var damage_flash: ColorRect
var hit_timer := 0.0
var damage_timer := 0.0

func _ready() -> void:
    layer = 20
    _build()
    visible = false

func _process(delta: float) -> void:
    if hit_timer > 0:
        hit_timer -= delta
        hit_marker.modulate.a = clampf(hit_timer * 5.0, 0, 1)
    if damage_timer > 0:
        damage_timer -= delta
        damage_flash.color.a = clampf(damage_timer * 0.32, 0, 0.18)

func _build() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    damage_flash = ColorRect.new()
    damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    damage_flash.color = Color(0.8, 0.02, 0.01, 0)
    damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(damage_flash)

    var top := HBoxContainer.new()
    top.set_anchors_preset(Control.PRESET_CENTER_TOP)
    top.position = Vector2(-225, 18)
    top.custom_minimum_size = Vector2(450, 55)
    top.alignment = BoxContainer.ALIGNMENT_CENTER
    top.add_theme_constant_override("separation", 22)
    root.add_child(top)
    mode_label = _label("TEAM DEATHMATCH", 16, Color("a8bed0"))
    score_label = _label("0  —  0", 30, Color.WHITE)
    timer_label = _label("05:00", 24, Color("e8c86e"))
    top.add_child(mode_label)
    top.add_child(score_label)
    top.add_child(timer_label)

    objective_label = _label("", 18, Color("f1d879"))
    objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    objective_label.position = Vector2(-250, 76)
    objective_label.custom_minimum_size = Vector2(500, 30)
    root.add_child(objective_label)

    health_label = _label("100", 34, Color.WHITE)
    health_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    health_label.position = Vector2(38, -85)
    health_label.custom_minimum_size = Vector2(130, 55)
    root.add_child(health_label)
    var health_caption := _label("HEALTH", 13, Color("8da5b5"))
    health_caption.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    health_caption.position = Vector2(42, -104)
    root.add_child(health_caption)

    ammo_label = _label("30 / 120", 32, Color.WHITE)
    ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    ammo_label.position = Vector2(-220, -84)
    ammo_label.custom_minimum_size = Vector2(180, 48)
    root.add_child(ammo_label)
    weapon_label = _label("AK-47", 15, Color("94adbd"))
    weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    weapon_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    weapon_label.position = Vector2(-220, -105)
    weapon_label.custom_minimum_size = Vector2(180, 25)
    root.add_child(weapon_label)

    kill_feed = VBoxContainer.new()
    kill_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    kill_feed.position = Vector2(-340, 85)
    kill_feed.custom_minimum_size = Vector2(310, 160)
    kill_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
    root.add_child(kill_feed)

    status_label = _label("", 24, Color.WHITE)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.set_anchors_preset(Control.PRESET_CENTER)
    status_label.position = Vector2(-290, -115)
    status_label.custom_minimum_size = Vector2(580, 50)
    root.add_child(status_label)

    var crosshair := Control.new()
    crosshair.set_anchors_preset(Control.PRESET_CENTER)
    crosshair.position = Vector2(-12, -12)
    crosshair.custom_minimum_size = Vector2(24, 24)
    crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(crosshair)
    for rect_data in [Rect2(11, 1, 2, 7), Rect2(11, 16, 2, 7), Rect2(1, 11, 7, 2), Rect2(16, 11, 7, 2)]:
        var segment := ColorRect.new()
        segment.position = rect_data.position
        segment.size = rect_data.size
        segment.color = Color(1, 1, 1, 0.86)
        crosshair.add_child(segment)

    hit_marker = Control.new()
    hit_marker.set_anchors_preset(Control.PRESET_CENTER)
    hit_marker.position = Vector2(-18, -18)
    hit_marker.custom_minimum_size = Vector2(36, 36)
    hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hit_marker.modulate.a = 0
    root.add_child(hit_marker)
    for data in [Rect2(6, 7, 9, 2), Rect2(21, 7, 9, 2), Rect2(6, 27, 9, 2), Rect2(21, 27, 9, 2)]:
        var line := ColorRect.new()
        line.position = data.position
        line.size = data.size
        line.color = Color("f6e6c8")
        if data.position.x < 18: line.rotation = PI / 4.0
        else: line.rotation = -PI / 4.0
        hit_marker.add_child(line)

func set_match_visible(value: bool) -> void:
    visible = value

func update_score(alpha: int, bravo: int, time_left: float, mode_name: String) -> void:
    score_label.text = "%02d  —  %02d" % [alpha, bravo]
    timer_label.text = "%02d:%02d" % [int(time_left) / 60, int(time_left) % 60]
    mode_label.text = mode_name.to_upper()

func update_health(value: int) -> void:
    health_label.text = str(value)
    health_label.modulate = Color("ef6f62") if value <= 30 else Color.WHITE

func update_weapon(title: String, ammo: int, reserve: int) -> void:
    weapon_label.text = title.to_upper()
    ammo_label.text = "%d / %d" % [ammo, reserve]
    ammo_label.modulate = Color("ef7868") if ammo <= 3 else Color.WHITE

func update_objective(text: String) -> void:
    objective_label.text = text

func show_status(text: String, color := Color.WHITE) -> void:
    status_label.text = text
    status_label.modulate = color

func show_hit(headshot: bool = false) -> void:
    hit_timer = 0.24
    hit_marker.modulate = Color("ffca62") if headshot else Color.WHITE

func show_damage() -> void:
    damage_timer = 0.55

func add_kill(killer_name: String, victim_name: String, weapon_name: String, headshot: bool = false) -> void:
    var row := _label("%s  › %s  %s%s" % [killer_name, victim_name, weapon_name, "  HS" if headshot else ""], 14, Color("e7eef4"))
    row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    kill_feed.add_child(row)
    if kill_feed.get_child_count() > 5: kill_feed.get_child(0).queue_free()
    var tween := create_tween()
    tween.tween_interval(4.0)
    tween.tween_property(row, "modulate:a", 0.0, 1.0)
    tween.tween_callback(row.queue_free)

func clear_feed() -> void:
    for child in kill_feed.get_children(): child.queue_free()

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

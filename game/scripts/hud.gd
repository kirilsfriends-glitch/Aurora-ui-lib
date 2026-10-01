extends CanvasLayer

var score_alpha: Label
var score_bravo: Label
var timer_label: Label
var health_label: Label
var ammo_label: Label
var weapon_label: Label
var location_label: Label
var objective_label: Label
var status_label: Label
var kill_feed: VBoxContainer
var hit_marker: Control
var damage_flash: ColorRect
var reload_bar: ProgressBar
var hit_audio: AudioStreamPlayer
var headshot_audio: AudioStreamPlayer
var hit_timer := 0.0
var damage_timer := 0.0

func _ready() -> void:
    layer = 20
    _build_interface()
    _setup_audio()
    visible = false

func _process(delta: float) -> void:
    if hit_timer > 0:
        hit_timer -= delta
        hit_marker.modulate.a = clampf(hit_timer * 6.5, 0, 1)
    if damage_timer > 0:
        damage_timer -= delta
        damage_flash.color.a = clampf(damage_timer * 0.38, 0, 0.22)

func _build_interface() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    damage_flash = ColorRect.new()
    damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    damage_flash.color = Color(0.76, 0.025, 0.01, 0)
    damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(damage_flash)

    location_label = _label("MID SERVICE LANE", 11, Color("a8c1c8"), true)
    location_label.position = Vector2(30, 24)
    location_label.custom_minimum_size = Vector2(250, 25)
    root.add_child(location_label)
    var operation := _label("DOCKYARD / NIGHT", 10, Color("4ccbd0"), true)
    operation.position = Vector2(30, 45)
    root.add_child(operation)

    var score_panel := PanelContainer.new()
    score_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
    score_panel.position = Vector2(-215, 18)
    score_panel.custom_minimum_size = Vector2(430, 66)
    score_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.033, 0.044, 0.88), Color(0.24, 0.45, 0.5, 0.46), 1, 4))
    root.add_child(score_panel)
    var score_row := HBoxContainer.new()
    score_row.alignment = BoxContainer.ALIGNMENT_CENTER
    score_row.add_theme_constant_override("separation", 16)
    score_panel.add_child(score_row)
    var alpha_tag := _score_column("ALPHA", Color("4dd5df"), true)
    score_alpha = alpha_tag.get_node("Score") as Label
    score_row.add_child(alpha_tag)
    var timer_column := VBoxContainer.new()
    timer_column.custom_minimum_size = Vector2(115, 58)
    timer_column.alignment = BoxContainer.ALIGNMENT_CENTER
    timer_label = _label("05:00", 25, Color.WHITE, true)
    timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    timer_column.add_child(timer_label)
    var mode := _label("TEAM DEATHMATCH", 9, Color("758f98"), true)
    mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    timer_column.add_child(mode)
    score_row.add_child(timer_column)
    var bravo_tag := _score_column("BRAVO", Color("ff795e"), false)
    score_bravo = bravo_tag.get_node("Score") as Label
    score_row.add_child(bravo_tag)

    objective_label = _label("FIRST SQUAD TO 30 ELIMINATIONS", 11, Color("c7d6da"), true)
    objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    objective_label.position = Vector2(-240, 94)
    objective_label.custom_minimum_size = Vector2(480, 24)
    root.add_child(objective_label)

    var health_panel := PanelContainer.new()
    health_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    health_panel.position = Vector2(29, -100)
    health_panel.custom_minimum_size = Vector2(174, 68)
    health_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.035, 0.045, 0.8), Color(0.22, 0.49, 0.52, 0.38), 1, 3))
    root.add_child(health_panel)
    var health_row := HBoxContainer.new()
    health_row.add_theme_constant_override("separation", 12)
    health_panel.add_child(health_row)
    var health_bar := ColorRect.new()
    health_bar.custom_minimum_size = Vector2(5, 68)
    health_bar.color = Color("43ced0")
    health_row.add_child(health_bar)
    var health_content := VBoxContainer.new()
    health_content.alignment = BoxContainer.ALIGNMENT_CENTER
    health_content.add_child(_label("OPERATOR HEALTH", 9, Color("708e98"), true))
    health_label = _label("100", 31, Color.WHITE, true)
    health_content.add_child(health_label)
    health_row.add_child(health_content)

    var ammo_panel := PanelContainer.new()
    ammo_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    ammo_panel.position = Vector2(-238, -100)
    ammo_panel.custom_minimum_size = Vector2(208, 68)
    ammo_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.035, 0.045, 0.8), Color(0.22, 0.49, 0.52, 0.38), 1, 3))
    root.add_child(ammo_panel)
    var ammo_content := VBoxContainer.new()
    ammo_content.alignment = BoxContainer.ALIGNMENT_CENTER
    ammo_content.add_theme_constant_override("separation", -2)
    ammo_panel.add_child(ammo_content)
    weapon_label = _label("AK-47", 10, Color("76a3ac"), true)
    weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    ammo_content.add_child(weapon_label)
    ammo_label = _label("30  /  90", 28, Color.WHITE, true)
    ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    ammo_content.add_child(ammo_label)

    reload_bar = ProgressBar.new()
    reload_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    reload_bar.position = Vector2(-238, -26)
    reload_bar.custom_minimum_size = Vector2(208, 4)
    reload_bar.show_percentage = false
    reload_bar.min_value = 0
    reload_bar.max_value = 1
    reload_bar.value = 0
    var reload_bg := StyleBoxFlat.new()
    reload_bg.bg_color = Color(0.04, 0.09, 0.11, 0.7)
    reload_bar.add_theme_stylebox_override("background", reload_bg)
    var reload_fill := StyleBoxFlat.new()
    reload_fill.bg_color = Color("42cbd0")
    reload_bar.add_theme_stylebox_override("fill", reload_fill)
    root.add_child(reload_bar)

    kill_feed = VBoxContainer.new()
    kill_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    kill_feed.position = Vector2(-370, 31)
    kill_feed.custom_minimum_size = Vector2(340, 180)
    kill_feed.add_theme_constant_override("separation", 5)
    root.add_child(kill_feed)

    status_label = _label("", 25, Color.WHITE, true)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.set_anchors_preset(Control.PRESET_CENTER)
    status_label.position = Vector2(-320, -128)
    status_label.custom_minimum_size = Vector2(640, 58)
    root.add_child(status_label)

    _build_crosshair(root)

func _score_column(title: String, color: Color, left: bool) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.name = title
    column.custom_minimum_size = Vector2(118, 58)
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    var caption := _label(title, 9, color, true)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
    column.add_child(caption)
    var score := _label("00", 28, Color.WHITE, true)
    score.name = "Score"
    score.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
    column.add_child(score)
    return column

func _build_crosshair(root: Control) -> void:
    var crosshair := Control.new()
    crosshair.set_anchors_preset(Control.PRESET_CENTER)
    crosshair.position = Vector2(-14, -14)
    crosshair.custom_minimum_size = Vector2(28, 28)
    root.add_child(crosshair)
    for data in [Rect2(13, 1, 2, 7), Rect2(13, 20, 2, 7), Rect2(1, 13, 7, 2), Rect2(20, 13, 7, 2)]:
        var segment := ColorRect.new()
        segment.position = data.position
        segment.size = data.size
        segment.color = Color(0.9, 0.97, 0.98, 0.88)
        crosshair.add_child(segment)
    var dot := ColorRect.new()
    dot.position = Vector2(13, 13)
    dot.size = Vector2(2, 2)
    dot.color = Color("55d6d7")
    crosshair.add_child(dot)

    hit_marker = Control.new()
    hit_marker.set_anchors_preset(Control.PRESET_CENTER)
    hit_marker.position = Vector2(-20, -20)
    hit_marker.custom_minimum_size = Vector2(40, 40)
    hit_marker.modulate.a = 0
    root.add_child(hit_marker)
    for data in [Rect2(5, 7, 11, 2), Rect2(24, 7, 11, 2), Rect2(5, 31, 11, 2), Rect2(24, 31, 11, 2)]:
        var line := ColorRect.new()
        line.position = data.position
        line.size = data.size
        line.color = Color.WHITE
        line.rotation = PI / 4.0 if data.position.x < 20 else -PI / 4.0
        hit_marker.add_child(line)

func _setup_audio() -> void:
    hit_audio = AudioStreamPlayer.new()
    headshot_audio = AudioStreamPlayer.new()
    if ResourceLoader.exists("res://audio/hit_confirm.wav"):
        hit_audio.stream = load("res://audio/hit_confirm.wav")
    if ResourceLoader.exists("res://audio/headshot_confirm.wav"):
        headshot_audio.stream = load("res://audio/headshot_confirm.wav")
    hit_audio.volume_db = -5.0
    headshot_audio.volume_db = -4.0
    add_child(hit_audio)
    add_child(headshot_audio)

func set_match_visible(value: bool) -> void:
    visible = value

func update_score(alpha: int, bravo: int, time_left: float, _mode_name: String = "") -> void:
    score_alpha.text = "%02d" % alpha
    score_bravo.text = "%02d" % bravo
    timer_label.text = "%02d:%02d" % [int(time_left) / 60, int(time_left) % 60]

func update_health(value: int) -> void:
    health_label.text = "%03d" % value
    health_label.modulate = Color("ff7668") if value <= 30 else Color.WHITE

func update_weapon(title: String, ammo: int, reserve: int) -> void:
    weapon_label.text = title.to_upper()
    ammo_label.text = "%02d  /  %03d" % [maxi(ammo, 0), maxi(reserve, 0)]
    ammo_label.modulate = Color("ff846e") if ammo <= 3 else Color.WHITE
    reload_bar.value = 1.0 if "RELOADING" in title else 0.0

func update_location(text: String) -> void:
    location_label.text = text.to_upper()

func update_objective(text: String) -> void:
    objective_label.text = text.to_upper()

func show_status(text: String, color := Color.WHITE) -> void:
    status_label.text = text
    status_label.modulate = color

func show_hit(headshot: bool = false) -> void:
    hit_timer = 0.22
    hit_marker.modulate = Color("ffc36b") if headshot else Color.WHITE
    if headshot and is_instance_valid(headshot_audio): headshot_audio.play()
    elif is_instance_valid(hit_audio): hit_audio.play()

func show_damage() -> void:
    damage_timer = 0.55

func add_kill(killer_name: String, victim_name: String, weapon_name: String, headshot: bool = false) -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.032, 0.042, 0.78), Color(0.23, 0.44, 0.48, 0.38), 1, 2))
    var row := _label("%s   ›   %s    %s%s" % [killer_name, victim_name, weapon_name, "  HEAD" if headshot else ""], 12, Color("e4eef0"), false)
    row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    panel.add_child(row)
    kill_feed.add_child(panel)
    if kill_feed.get_child_count() > 5: kill_feed.get_child(0).queue_free()
    var tween := create_tween()
    tween.tween_interval(4.2)
    tween.tween_property(panel, "modulate:a", 0.0, 0.8)
    tween.tween_callback(panel.queue_free)

func clear_feed() -> void:
    for child in kill_feed.get_children(): child.queue_free()

func _panel_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 6
    style.content_margin_bottom = 6
    return style

func _label(text: String, size: int, color: Color, _tracking: bool) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 2)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

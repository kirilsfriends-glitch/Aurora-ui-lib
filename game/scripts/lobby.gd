extends CanvasLayer

signal deployment_requested(weapon_id: String, difficulty: float)

const LOADOUTS := {
    "ak47": {"title": "AK-47", "role": "ASSAULT", "detail": "Heavy 7.62 damage • controllable tap fire", "ammo": "30 / 90"},
    "m4a1": {"title": "M4A1", "role": "ASSAULT", "detail": "Low recoil • fast follow-up shots", "ammo": "30 / 90"},
    "awp": {"title": "AWP", "role": "SNIPER", "detail": "High-caliber bolt action • 4× optic", "ammo": "10 / 30"},
    "glock": {"title": "GLOCK-18", "role": "MOBILITY", "detail": "Fast handling • close-range sidearm", "ammo": "20 / 80"},
}
const LOADOUT_ORDER := ["ak47", "m4a1", "awp", "glock"]

var root: Control
var selected_weapon := "ak47"
var weapon_cards: Dictionary = {}
var selection_title: Label
var selection_detail: Label
var selection_ammo: Label
var difficulty_picker: OptionButton
var result_layer: Control
var briefing_panel: Control
var ui_audio: AudioStreamPlayer

func _ready() -> void:
    layer = 30
    _build_interface()
    _select_weapon("ak47", false)

func _build_interface() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var background := TextureRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.texture = load("res://ui/dockyard_briefing.webp")
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(background)

    var dim := ColorRect.new()
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.color = Color(0.015, 0.025, 0.035, 0.34)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(dim)

    var left_gradient := ColorRect.new()
    left_gradient.position = Vector2(0, 0)
    left_gradient.size = Vector2(510, 720)
    left_gradient.color = Color(0.018, 0.035, 0.047, 0.94)
    left_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(left_gradient)

    var accent := ColorRect.new()
    accent.position = Vector2(0, 0)
    accent.size = Vector2(5, 720)
    accent.color = Color("35c8d2")
    root.add_child(accent)

    var brand := _label("AURORA / STRIKE", 27, Color("eef8fa"), true)
    brand.position = Vector2(42, 28)
    root.add_child(brand)
    var build := _label("TACTICAL MOBILE UNIT    //    VERTICAL SLICE 0.2", 11, Color("49cbd1"), true)
    build.position = Vector2(44, 63)
    root.add_child(build)
    var line := ColorRect.new()
    line.position = Vector2(43, 91)
    line.size = Vector2(412, 1)
    line.color = Color(0.3, 0.72, 0.74, 0.35)
    root.add_child(line)

    var operation := _label("OPERATION", 12, Color("7f9ca8"), true)
    operation.position = Vector2(43, 123)
    root.add_child(operation)
    var map_title := _label("DOCKYARD / NIGHT", 36, Color.WHITE, true)
    map_title.position = Vector2(40, 143)
    root.add_child(map_title)
    var location := _label("KOLA SHIPPING TERMINAL  •  02:40 LOCAL", 12, Color("6ad5d7"), false)
    location.position = Vector2(44, 191)
    root.add_child(location)

    var mission_panel := PanelContainer.new()
    mission_panel.position = Vector2(42, 232)
    mission_panel.custom_minimum_size = Vector2(414, 157)
    mission_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.06, 0.075, 0.88), Color(0.24, 0.5, 0.54, 0.46), 1, 4))
    root.add_child(mission_panel)
    var mission_margin := MarginContainer.new()
    mission_margin.add_theme_constant_override("margin_left", 18)
    mission_margin.add_theme_constant_override("margin_right", 18)
    mission_margin.add_theme_constant_override("margin_top", 15)
    mission_margin.add_theme_constant_override("margin_bottom", 15)
    mission_panel.add_child(mission_margin)
    var mission := VBoxContainer.new()
    mission.add_theme_constant_override("separation", 7)
    mission_margin.add_child(mission)
    mission.add_child(_label("TEAM DEATHMATCH", 18, Color("e9f5f6"), true))
    mission.add_child(_label("FIRST SQUAD TO 30 ELIMINATIONS", 12, Color("f0a76b"), true))
    var brief := _label("Secure three container lanes. Use Customs as hard cover. Gunfire reveals positions to both squads.", 14, Color("9db1b9"), false)
    brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    brief.custom_minimum_size = Vector2(370, 57)
    mission.add_child(brief)

    var difficulty_caption := _label("HOSTILE RESPONSE", 11, Color("7896a1"), true)
    difficulty_caption.position = Vector2(43, 420)
    root.add_child(difficulty_caption)
    difficulty_picker = OptionButton.new()
    difficulty_picker.position = Vector2(42, 441)
    difficulty_picker.custom_minimum_size = Vector2(414, 48)
    difficulty_picker.add_item("RECRUIT  /  48% combat accuracy")
    difficulty_picker.set_item_metadata(0, 0.48)
    difficulty_picker.add_item("VETERAN  /  70% combat accuracy")
    difficulty_picker.set_item_metadata(1, 0.70)
    difficulty_picker.add_item("ELITE  /  88% combat accuracy")
    difficulty_picker.set_item_metadata(2, 0.88)
    difficulty_picker.select(1)
    _style_button(difficulty_picker, Color("367d85"), 14)
    root.add_child(difficulty_picker)

    var systems := VBoxContainer.new()
    systems.position = Vector2(43, 516)
    systems.add_theme_constant_override("separation", 6)
    root.add_child(systems)
    systems.add_child(_status_row("●", "5v5 OFFLINE TACTICAL AI", Color("52d4ca")))
    systems.add_child(_status_row("●", "VISION / HEARING / COVER ROUTING", Color("52d4ca")))
    systems.add_child(_status_row("●", "RAIN / ORIGINAL AUDIO / PBR ASSETS", Color("52d4ca")))

    var deploy := Button.new()
    deploy.text = "DEPLOY  ›"
    deploy.position = Vector2(42, 625)
    deploy.custom_minimum_size = Vector2(414, 61)
    deploy.pressed.connect(_deploy)
    _style_button(deploy, Color("24aeb7"), 17, true)
    root.add_child(deploy)

    _build_briefing_card()
    _build_loadout_strip()
    _build_result_layer()
    _setup_audio()

func _build_briefing_card() -> void:
    briefing_panel = PanelContainer.new()
    briefing_panel.position = Vector2(894, 42)
    briefing_panel.custom_minimum_size = Vector2(342, 189)
    briefing_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.035, 0.046, 0.9), Color(0.27, 0.61, 0.64, 0.55), 1, 5))
    root.add_child(briefing_panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_top", 17)
    margin.add_theme_constant_override("margin_bottom", 16)
    briefing_panel.add_child(margin)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 6)
    margin.add_child(content)
    content.add_child(_label("SELECTED PRIMARY", 10, Color("6f929c"), true))
    selection_title = _label("AK-47", 29, Color.WHITE, true)
    content.add_child(selection_title)
    selection_detail = _label("Heavy 7.62 damage • controllable tap fire", 13, Color("a6bcc3"), false)
    selection_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    selection_detail.custom_minimum_size.y = 42
    content.add_child(selection_detail)
    var ammo_row := HBoxContainer.new()
    ammo_row.add_child(_label("READY AMMUNITION", 10, Color("64848e"), true))
    selection_ammo = _label("30 / 90", 15, Color("ebac72"), true)
    selection_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    selection_ammo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ammo_row.add_child(selection_ammo)
    content.add_child(ammo_row)

func _build_loadout_strip() -> void:
    var strip_bg := ColorRect.new()
    strip_bg.position = Vector2(500, 506)
    strip_bg.size = Vector2(780, 214)
    strip_bg.color = Color(0.012, 0.028, 0.037, 0.92)
    root.add_child(strip_bg)
    var heading := _label("CHOOSE LOADOUT", 12, Color("75a3ac"), true)
    heading.position = Vector2(527, 526)
    root.add_child(heading)
    var note := _label("Four tuned weapons for the quality slice", 11, Color("5e747c"), false)
    note.position = Vector2(1050, 527)
    root.add_child(note)

    var row := HBoxContainer.new()
    row.position = Vector2(523, 560)
    row.custom_minimum_size = Vector2(730, 132)
    row.add_theme_constant_override("separation", 10)
    root.add_child(row)
    for weapon_id in LOADOUT_ORDER:
        var info: Dictionary = LOADOUTS[weapon_id]
        var card := Button.new()
        card.custom_minimum_size = Vector2(175, 128)
        card.text = "%s\n\n%s\n%s" % [info["role"], info["title"], info["ammo"]]
        card.alignment = HORIZONTAL_ALIGNMENT_LEFT
        card.pressed.connect(_select_weapon.bind(weapon_id, true))
        row.add_child(card)
        weapon_cards[weapon_id] = card

func _build_result_layer() -> void:
    result_layer = Control.new()
    result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result_layer.visible = false
    root.add_child(result_layer)
    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.005, 0.012, 0.018, 0.88)
    result_layer.add_child(shade)
    var panel := PanelContainer.new()
    panel.position = Vector2(383, 166)
    panel.custom_minimum_size = Vector2(514, 390)
    panel.add_theme_stylebox_override("panel", _panel_style(Color("0b1c25"), Color("42bdc4"), 2, 7))
    result_layer.add_child(panel)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 30)
    panel.add_child(margin)
    var content := VBoxContainer.new()
    content.name = "ResultContent"
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 17)
    margin.add_child(content)
    content.add_child(_label("OPERATION COMPLETE", 11, Color("79a6ae"), true))
    var title := _label("VICTORY", 46, Color("51d1ce"), true)
    title.name = "Title"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(title)
    var detail := _label("ALPHA 30  —  24 BRAVO", 19, Color("d6e4e7"), true)
    detail.name = "Detail"
    detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.custom_minimum_size.y = 64
    content.add_child(detail)
    var return_button := Button.new()
    return_button.text = "RETURN TO BRIEFING"
    return_button.custom_minimum_size = Vector2(360, 57)
    return_button.pressed.connect(show_lobby)
    _style_button(return_button, Color("249ca5"), 15, true)
    content.add_child(return_button)

func _setup_audio() -> void:
    if not ResourceLoader.exists("res://audio/ui_confirm.wav"): return
    ui_audio = AudioStreamPlayer.new()
    ui_audio.stream = load("res://audio/ui_confirm.wav")
    ui_audio.volume_db = -7.0
    add_child(ui_audio)

func _select_weapon(weapon_id: String, play_sound: bool) -> void:
    selected_weapon = weapon_id
    var info: Dictionary = LOADOUTS[weapon_id]
    selection_title.text = info["title"]
    selection_detail.text = info["detail"]
    selection_ammo.text = info["ammo"]
    for id in weapon_cards:
        _style_loadout_card(weapon_cards[id], id == weapon_id)
    if play_sound and is_instance_valid(ui_audio): ui_audio.play()

func _deploy() -> void:
    if is_instance_valid(ui_audio): ui_audio.play()
    var difficulty := float(difficulty_picker.get_item_metadata(difficulty_picker.selected))
    root.visible = false
    deployment_requested.emit(selected_weapon, difficulty)

func show_lobby() -> void:
    root.visible = true
    result_layer.visible = false

func show_result(title: String, detail: String, victory: bool) -> void:
    root.visible = true
    result_layer.visible = true
    var content := result_layer.find_child("ResultContent", true, false)
    var title_label := content.get_node("Title") as Label
    var detail_label := content.get_node("Detail") as Label
    title_label.text = title
    title_label.modulate = Color("51d1ce") if victory else Color("f17869")
    detail_label.text = detail

func _style_loadout_card(button: Button, selected: bool) -> void:
    var base := Color("17313b") if selected else Color("101e26")
    var border := Color("42cad0") if selected else Color("2c4a53")
    var style := _panel_style(base, border, 2 if selected else 1, 4)
    style.content_margin_left = 14
    style.content_margin_top = 13
    button.add_theme_stylebox_override("normal", style)
    var hover := style.duplicate() as StyleBoxFlat
    hover.bg_color = Color("1c3f49")
    hover.border_color = Color("5bd5d8")
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", Color.WHITE if selected else Color("a4b7bd"))

func _style_button(button: BaseButton, accent_color: Color, font_size: int, strong := false) -> void:
    button.add_theme_font_size_override("font_size", font_size)
    button.add_theme_color_override("font_color", Color("f1f8f9"))
    var normal := _panel_style(accent_color.darkened(0.54 if strong else 0.72), accent_color, 1, 4)
    normal.content_margin_left = 16
    normal.content_margin_right = 16
    button.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = accent_color.darkened(0.36)
    hover.border_color = accent_color.lightened(0.28)
    button.add_theme_stylebox_override("hover", hover)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = accent_color.darkened(0.2)
    button.add_theme_stylebox_override("pressed", pressed)

func _status_row(symbol: String, text: String, color: Color) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 9)
    row.add_child(_label(symbol, 11, color, true))
    row.add_child(_label(text, 11, Color("91a7af"), true))
    return row

func _panel_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(radius)
    return style

func _label(text: String, size: int, color: Color, uppercase_spacing: bool) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.66))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 2)
    if uppercase_spacing: label.add_theme_constant_override("outline_size", 0)
    return label

extends CanvasLayer

signal match_requested(map_id: String, mode_id: String, difficulty: float)

const MAP_LIBRARY := preload("res://scripts/map_library.gd")

var root: Control
var cards: Dictionary = {}
var votes: Dictionary = {}
var player_vote := "dockyard"
var mode_picker: OptionButton
var difficulty_picker: OptionButton
var deploy_button: Button
var result_overlay: PanelContainer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    layer = 30
    rng.randomize()
    _build()
    _run_bot_vote()

func _build() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("071019")
    root.add_child(background)
    var glow := ColorRect.new()
    glow.set_anchors_preset(Control.PRESET_FULL_RECT)
    glow.color = Color(0.03, 0.19, 0.25, 0.26)
    glow.position = Vector2(0, 0)
    root.add_child(glow)

    var header := VBoxContainer.new()
    header.position = Vector2(54, 35)
    header.custom_minimum_size = Vector2(760, 100)
    header.add_theme_constant_override("separation", -4)
    root.add_child(header)
    var eyebrow := _label("AURORA TACTICAL COMMAND // MOBILE UNIT", 14, Color("57d1d9"))
    header.add_child(eyebrow)
    var title := _label("AURORA STRIKE", 46, Color("eef6f8"))
    header.add_child(title)
    var subtitle := _label("SELECT OPERATION  •  BOTS ARE CASTING THEIR VOTES", 15, Color("8199a7"))
    header.add_child(subtitle)

    var setup_panel := HBoxContainer.new()
    setup_panel.position = Vector2(790, 42)
    setup_panel.custom_minimum_size = Vector2(430, 72)
    setup_panel.add_theme_constant_override("separation", 14)
    root.add_child(setup_panel)
    var mode_column := VBoxContainer.new()
    mode_column.add_child(_label("MODE", 12, Color("8199a7")))
    mode_picker = OptionButton.new()
    mode_picker.custom_minimum_size = Vector2(198, 44)
    mode_picker.add_item("Team Deathmatch")
    mode_picker.set_item_metadata(0, "tdm")
    mode_picker.add_item("Elimination")
    mode_picker.set_item_metadata(1, "elimination")
    mode_picker.add_item("Control")
    mode_picker.set_item_metadata(2, "control")
    _style_button(mode_picker)
    mode_column.add_child(mode_picker)
    setup_panel.add_child(mode_column)
    var difficulty_column := VBoxContainer.new()
    difficulty_column.add_child(_label("BOT DIFFICULTY", 12, Color("8199a7")))
    difficulty_picker = OptionButton.new()
    difficulty_picker.custom_minimum_size = Vector2(198, 44)
    difficulty_picker.add_item("Recruit")
    difficulty_picker.set_item_metadata(0, 0.48)
    difficulty_picker.add_item("Veteran")
    difficulty_picker.set_item_metadata(1, 0.70)
    difficulty_picker.add_item("Elite")
    difficulty_picker.set_item_metadata(2, 0.88)
    difficulty_picker.select(1)
    _style_button(difficulty_picker)
    difficulty_column.add_child(difficulty_picker)
    setup_panel.add_child(difficulty_column)

    var maps_row := HBoxContainer.new()
    maps_row.position = Vector2(42, 154)
    maps_row.custom_minimum_size = Vector2(1196, 398)
    maps_row.add_theme_constant_override("separation", 12)
    root.add_child(maps_row)
    var accent_colors := [Color("198a96"), Color("b17b49"), Color("5c6fc1"), Color("77a9c4"), Color("a24bb5")]
    for i in MAP_LIBRARY.MAP_ORDER.size():
        var map_id: String = MAP_LIBRARY.MAP_ORDER[i]
        var info: Dictionary = MAP_LIBRARY.get_map(map_id)
        var card := VBoxContainer.new()
        card.custom_minimum_size = Vector2(229, 390)
        card.add_theme_constant_override("separation", 8)
        maps_row.add_child(card)
        var banner := ColorRect.new()
        banner.custom_minimum_size = Vector2(229, 124)
        banner.color = accent_colors[i].darkened(0.35)
        card.add_child(banner)
        var symbol := Label.new()
        symbol.text = ["D-01", "C-02", "M-03", "F-04", "N-05"][i]
        symbol.position = Vector2(16, 16)
        symbol.add_theme_font_size_override("font_size", 30)
        symbol.add_theme_color_override("font_color", accent_colors[i].lightened(0.35))
        banner.add_child(symbol)
        var zone := Label.new()
        zone.text = str(info["subtitle"]).to_upper()
        zone.position = Vector2(17, 84)
        zone.add_theme_font_size_override("font_size", 11)
        zone.add_theme_color_override("font_color", Color(1, 1, 1, 0.67))
        banner.add_child(zone)
        var map_name := _label(str(info["name"]).to_upper(), 20, Color("edf5f7"))
        map_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        map_name.custom_minimum_size = Vector2(220, 53)
        card.add_child(map_name)
        var description := _label(_map_description(map_id), 13, Color("8fa4af"))
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        description.custom_minimum_size = Vector2(220, 82)
        card.add_child(description)
        var vote_label := _label("0 BOT VOTES", 13, Color("67d5d7"))
        vote_label.name = "VoteLabel"
        card.add_child(vote_label)
        var vote_button := Button.new()
        vote_button.text = "VOTE"
        vote_button.custom_minimum_size = Vector2(220, 49)
        vote_button.pressed.connect(_cast_player_vote.bind(map_id))
        _style_button(vote_button, accent_colors[i])
        card.add_child(vote_button)
        cards[map_id] = {"button": vote_button, "votes": vote_label}

    var footer := HBoxContainer.new()
    footer.position = Vector2(44, 595)
    footer.custom_minimum_size = Vector2(1190, 82)
    footer.alignment = BoxContainer.ALIGNMENT_END
    footer.add_theme_constant_override("separation", 20)
    root.add_child(footer)
    var details := VBoxContainer.new()
    details.custom_minimum_size = Vector2(740, 70)
    details.add_child(_label("5v5  •  FIRST-PERSON  •  OFFLINE SMART AI", 18, Color("d8e4e8")))
    var detail_note := _label("Nine AI operatives vote independently. Highest-voted operation deploys.", 13, Color("748b98"))
    details.add_child(detail_note)
    footer.add_child(details)
    deploy_button = Button.new()
    deploy_button.text = "DEPLOY SQUAD"
    deploy_button.custom_minimum_size = Vector2(310, 64)
    deploy_button.pressed.connect(_deploy)
    _style_button(deploy_button, Color("23a6aa"))
    footer.add_child(deploy_button)

    _build_result_overlay()

func _run_bot_vote() -> void:
    votes.clear()
    for map_id in MAP_LIBRARY.MAP_ORDER: votes[map_id] = 0
    for _bot in 9:
        var map_id: String = MAP_LIBRARY.MAP_ORDER[rng.randi_range(0, MAP_LIBRARY.MAP_ORDER.size() - 1)]
        votes[map_id] += 1
    _cast_player_vote(player_vote)

func _cast_player_vote(map_id: String) -> void:
    if votes.has(player_vote) and cards.has(player_vote) and cards[player_vote]["button"].text == "VOTED":
        votes[player_vote] = maxi(0, int(votes[player_vote]) - 1)
    player_vote = map_id
    votes[map_id] = int(votes[map_id]) + 1
    for id in cards:
        var count := int(votes[id])
        cards[id]["votes"].text = "%d VOTE%s" % [count, "" if count == 1 else "S"]
        cards[id]["button"].text = "VOTED" if id == player_vote else "VOTE"

func _deploy() -> void:
    var winner := player_vote
    var highest := -1
    var tied: Array[String] = []
    for map_id in MAP_LIBRARY.MAP_ORDER:
        var count := int(votes[map_id])
        if count > highest:
            highest = count
            tied.assign([map_id])
        elif count == highest:
            tied.append(map_id)
    if not tied.is_empty(): winner = tied[rng.randi_range(0, tied.size() - 1)]
    var mode_id: String = str(mode_picker.get_item_metadata(mode_picker.selected))
    var difficulty: float = float(difficulty_picker.get_item_metadata(difficulty_picker.selected))
    root.visible = false
    match_requested.emit(winner, mode_id, difficulty)

func show_lobby() -> void:
    root.visible = true
    result_overlay.visible = false
    _run_bot_vote()

func show_result(title: String, detail: String, victory: bool) -> void:
    root.visible = true
    result_overlay.visible = true
    result_overlay.get_node("Result/Title").text = title
    result_overlay.get_node("Result/Title").modulate = Color("55d2cf") if victory else Color("ef7468")
    result_overlay.get_node("Result/Detail").text = detail

func _build_result_overlay() -> void:
    result_overlay = PanelContainer.new()
    result_overlay.position = Vector2(360, 190)
    result_overlay.custom_minimum_size = Vector2(560, 340)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("0b1721")
    style.border_color = Color("39727a")
    style.set_border_width_all(2)
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    result_overlay.add_theme_stylebox_override("panel", style)
    root.add_child(result_overlay)
    var result := VBoxContainer.new()
    result.name = "Result"
    result.alignment = BoxContainer.ALIGNMENT_CENTER
    result.add_theme_constant_override("separation", 20)
    result_overlay.add_child(result)
    var result_title := _label("VICTORY", 42, Color("55d2cf"))
    result_title.name = "Title"
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.add_child(result_title)
    var detail := _label("Operation complete", 19, Color("a8bac3"))
    detail.name = "Detail"
    detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.add_child(detail)
    var return_button := Button.new()
    return_button.text = "RETURN TO OPERATIONS"
    return_button.custom_minimum_size = Vector2(320, 58)
    return_button.pressed.connect(show_lobby)
    _style_button(return_button, Color("23a6aa"))
    result.add_child(return_button)
    result_overlay.visible = false

func _map_description(map_id: String) -> String:
    match map_id:
        "dockyard": return "Rain-swept containers, long crane lanes and close warehouse fights."
        "sandstone": return "Sunlit fortress with vertical courtyards and layered flank routes."
        "metro": return "Underground platforms, service tunnels and dangerous sightlines."
        "frostline": return "Arctic research base shaped by cover-rich exterior crossings."
        _: return "High-tech complex with neon corridors and a contested central reactor."

func _style_button(button: BaseButton, accent := Color("286b73")) -> void:
    button.add_theme_font_size_override("font_size", 15)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("11242e")
    normal.border_color = accent.darkened(0.1)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(4)
    normal.content_margin_left = 14
    normal.content_margin_right = 14
    button.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = accent.darkened(0.42)
    hover.border_color = accent.lightened(0.22)
    button.add_theme_stylebox_override("hover", hover)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = accent.darkened(0.2)
    pressed.border_color = accent.lightened(0.4)
    button.add_theme_stylebox_override("pressed", pressed)

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

extends Node3D

const MOVE_SPEED := 7.0
const ACCELERATION := 22.0
const AIR_ACCELERATION := 8.0
const JUMP_VELOCITY := 10.0
const GRAVITY := 26.0
const TOTAL_SHARDS := 10

var player: CharacterBody3D
var player_visual: Node3D
var camera: Camera3D
var spawn_point := Vector3(-10.0, 1.1, 10.0)
var shard_nodes: Array[Area3D] = []
var hazard_nodes: Array[Area3D] = []
var portal: Area3D
var portal_ring: MeshInstance3D
var portal_material: StandardMaterial3D

var score_label: Label
var timer_label: Label
var message_label: Label
var victory_panel: PanelContainer
var victory_time_label: Label

var collected := 0
var elapsed := 0.0
var hit_cooldown := 0.0
var message_until := 0.0
var won := false
var jump_requested := false
var touch_actions := {
    "left": false,
    "right": false,
    "forward": false,
    "back": false,
}


func _ready() -> void:
    _setup_input_actions()
    _build_environment()
    _build_arena()
    _spawn_player()
    _spawn_shards()
    _spawn_hazards()
    _spawn_portal()
    _build_interface()
    _update_hud()
    _show_message("COLLECT 10 AURORA SHARDS", 3.5)


func _process(delta: float) -> void:
    if not won:
        elapsed += delta
    hit_cooldown = maxf(0.0, hit_cooldown - delta)

    _animate_world(delta)
    _update_camera(delta)
    _update_hud()

    if message_until > 0.0 and Time.get_ticks_msec() / 1000.0 > message_until:
        message_until = 0.0
        message_label.text = ""


func _physics_process(delta: float) -> void:
    if won:
        player.velocity = player.velocity.move_toward(Vector3.ZERO, 12.0 * delta)
        player.move_and_slide()
        return

    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var touch_vector := Vector2(
        float(touch_actions["right"]) - float(touch_actions["left"]),
        float(touch_actions["back"]) - float(touch_actions["forward"])
    )
    if touch_vector.length_squared() > 0.0:
        input_vector = touch_vector.normalized()

    var direction := Vector3(input_vector.x, 0.0, input_vector.y)
    var acceleration := ACCELERATION if player.is_on_floor() else AIR_ACCELERATION
    var target_velocity := direction * MOVE_SPEED
    player.velocity.x = move_toward(player.velocity.x, target_velocity.x, acceleration * delta)
    player.velocity.z = move_toward(player.velocity.z, target_velocity.z, acceleration * delta)

    if player.is_on_floor():
        if Input.is_action_just_pressed("jump") or jump_requested:
            player.velocity.y = JUMP_VELOCITY
        else:
            player.velocity.y = -0.6
    else:
        player.velocity.y -= GRAVITY * delta
    jump_requested = false

    if direction.length_squared() > 0.01:
        var target_yaw := atan2(-direction.x, -direction.z)
        player_visual.rotation.y = lerp_angle(player_visual.rotation.y, target_yaw, 10.0 * delta)

    player.move_and_slide()

    if player.global_position.y < -5.0:
        _reset_player("THE VOID PULLED YOU BACK")


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("restart"):
        get_tree().reload_current_scene()


func _setup_input_actions() -> void:
    _ensure_key_action("move_left", [KEY_A, KEY_LEFT])
    _ensure_key_action("move_right", [KEY_D, KEY_RIGHT])
    _ensure_key_action("move_forward", [KEY_W, KEY_UP])
    _ensure_key_action("move_back", [KEY_S, KEY_DOWN])
    _ensure_key_action("jump", [KEY_SPACE])
    _ensure_key_action("restart", [KEY_R])


func _ensure_key_action(action: StringName, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if not InputMap.action_get_events(action).is_empty():
        return
    for key_code in keys:
        var key_event := InputEventKey.new()
        key_event.physical_keycode = key_code
        InputMap.action_add_event(action, key_event)


func _build_environment() -> void:
    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("07112e")
    environment.background_energy_multiplier = 0.75
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("8b9cff")
    environment.ambient_light_energy = 0.7
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_environment.environment = environment
    add_child(world_environment)

    var key_light := DirectionalLight3D.new()
    key_light.light_color = Color("b8d5ff")
    key_light.light_energy = 1.35
    key_light.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
    key_light.shadow_enabled = true
    add_child(key_light)

    var aurora_light := OmniLight3D.new()
    aurora_light.light_color = Color("39f4d4")
    aurora_light.light_energy = 7.0
    aurora_light.omni_range = 24.0
    aurora_light.position = Vector3(-8.0, 7.0, 2.0)
    add_child(aurora_light)

    var violet_light := OmniLight3D.new()
    violet_light.light_color = Color("b052ff")
    violet_light.light_energy = 6.0
    violet_light.omni_range = 22.0
    violet_light.position = Vector3(9.0, 5.0, -8.0)
    add_child(violet_light)


func _build_arena() -> void:
    var arena := Node3D.new()
    arena.name = "FloatingArena"
    add_child(arena)

    _add_static_box(arena, Vector3(26.0, 1.0, 26.0), Vector3(0.0, -0.55, 0.0), Color("101b4a"), 0.0)

    for x in range(-10, 11, 5):
        for z in range(-10, 11, 5):
            var tile_color := Color("12275a") if (x + z) % 10 == 0 else Color("172c67")
            _add_box_visual(arena, Vector3(4.72, 0.08, 4.72), Vector3(x, 0.01, z), tile_color, 0.15)

    var rail_color := Color("24dbc8")
    _add_static_box(arena, Vector3(26.6, 1.2, 0.35), Vector3(0.0, 0.6, -13.15), rail_color, 1.6)
    _add_static_box(arena, Vector3(26.6, 1.2, 0.35), Vector3(0.0, 0.6, 13.15), rail_color, 1.6)
    _add_static_box(arena, Vector3(0.35, 1.2, 26.6), Vector3(-13.15, 0.6, 0.0), rail_color, 1.6)
    _add_static_box(arena, Vector3(0.35, 1.2, 26.6), Vector3(13.15, 0.6, 0.0), rail_color, 1.6)

    var pylon_positions := [
        Vector3(-12.0, 1.7, -12.0), Vector3(12.0, 1.7, -12.0),
        Vector3(-12.0, 1.7, 12.0), Vector3(12.0, 1.7, 12.0),
    ]
    for pylon_position in pylon_positions:
        _add_box_visual(arena, Vector3(0.9, 3.4, 0.9), pylon_position, Color("7657ff"), 2.0)
        var cap := SphereMesh.new()
        cap.radius = 0.55
        cap.height = 1.1
        var cap_visual := MeshInstance3D.new()
        cap_visual.mesh = cap
        cap_visual.material_override = _make_material(Color("74fff0"), 2.5)
        cap_visual.position = pylon_position + Vector3(0.0, 2.1, 0.0)
        arena.add_child(cap_visual)

    _add_floating_islands(arena)


func _add_floating_islands(parent: Node3D) -> void:
    var island_data := [
        [Vector3(-19.0, -2.5, -8.0), Vector3(6.0, 1.2, 5.0), Color("1d225e")],
        [Vector3(18.0, -1.8, 7.0), Vector3(5.0, 0.9, 7.0), Color("242067")],
        [Vector3(-7.0, -3.3, 19.0), Vector3(7.0, 1.4, 4.0), Color("16245a")],
        [Vector3(8.0, -2.8, -20.0), Vector3(8.0, 1.1, 5.0), Color("252064")],
    ]
    for data in island_data:
        _add_box_visual(parent, data[1], data[0], data[2], 0.0)
        for offset in [-1.5, 0.0, 1.5]:
            var shard := BoxMesh.new()
            shard.size = Vector3(0.18, 2.5 + absf(offset), 0.18)
            var shard_visual := MeshInstance3D.new()
            shard_visual.mesh = shard
            shard_visual.material_override = _make_material(Color("914dff"), 1.3)
            shard_visual.position = data[0] + Vector3(offset, 1.7, 0.0)
            shard_visual.rotation_degrees = Vector3(0.0, 0.0, 12.0 * offset)
            parent.add_child(shard_visual)


func _spawn_player() -> void:
    player = CharacterBody3D.new()
    player.name = "AuroraDrone"
    player.position = spawn_point
    add_child(player)

    var collision := CollisionShape3D.new()
    var capsule_shape := CapsuleShape3D.new()
    capsule_shape.radius = 0.52
    capsule_shape.height = 1.35
    collision.shape = capsule_shape
    player.add_child(collision)

    player_visual = Node3D.new()
    player_visual.name = "DroneVisual"
    player.add_child(player_visual)

    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.52
    body_mesh.height = 1.35
    var body_visual := MeshInstance3D.new()
    body_visual.mesh = body_mesh
    body_visual.material_override = _make_material(Color("57c8ff"), 1.2)
    player_visual.add_child(body_visual)

    var visor_mesh := SphereMesh.new()
    visor_mesh.radius = 0.36
    visor_mesh.height = 0.5
    var visor := MeshInstance3D.new()
    visor.mesh = visor_mesh
    visor.scale = Vector3(1.0, 0.65, 0.45)
    visor.position = Vector3(0.0, 0.2, -0.48)
    visor.material_override = _make_material(Color("ecffff"), 3.0)
    player_visual.add_child(visor)

    _add_box_visual(player_visual, Vector3(1.65, 0.12, 0.55), Vector3(0.0, -0.2, 0.15), Color("9e5cff"), 1.6)
    _add_box_visual(player_visual, Vector3(0.22, 0.18, 1.2), Vector3(0.0, -0.15, 0.28), Color("4ef2d2"), 1.8)

    var drone_light := OmniLight3D.new()
    drone_light.light_color = Color("4ef2d2")
    drone_light.light_energy = 2.6
    drone_light.omni_range = 5.0
    drone_light.position = Vector3(0.0, 0.0, 0.4)
    player_visual.add_child(drone_light)

    camera = Camera3D.new()
    camera.name = "FollowCamera"
    camera.fov = 58.0
    camera.current = true
    camera.position = player.position + Vector3(0.0, 9.0, 11.0)
    add_child(camera)
    camera.look_at(player.position + Vector3(0.0, 0.7, 0.0))


func _spawn_shards() -> void:
    var positions := [
        Vector3(-10.0, 1.0, 5.0), Vector3(-6.0, 1.0, 0.0),
        Vector3(-10.0, 1.0, -8.0), Vector3(-2.0, 1.0, -10.0),
        Vector3(4.0, 1.0, -7.0), Vector3(10.0, 1.0, -2.0),
        Vector3(7.0, 1.0, 5.0), Vector3(10.0, 1.0, 10.0),
        Vector3(2.0, 1.0, 9.0), Vector3(-3.0, 1.0, 4.0),
    ]

    for index in positions.size():
        var shard := Area3D.new()
        shard.name = "AuroraShard%02d" % (index + 1)
        shard.position = positions[index]
        shard.set_meta("base_y", positions[index].y)
        shard.set_meta("phase", float(index) * 0.63)
        add_child(shard)

        var collision := CollisionShape3D.new()
        var shape := SphereShape3D.new()
        shape.radius = 0.82
        collision.shape = shape
        shard.add_child(collision)

        var crystal_mesh := BoxMesh.new()
        crystal_mesh.size = Vector3(0.55, 1.05, 0.55)
        var crystal := MeshInstance3D.new()
        crystal.mesh = crystal_mesh
        crystal.rotation_degrees = Vector3(0.0, 45.0, 45.0)
        crystal.material_override = _make_material(Color("54ffe1"), 3.0)
        shard.add_child(crystal)

        var halo_mesh := TorusMesh.new()
        halo_mesh.inner_radius = 0.68
        halo_mesh.outer_radius = 0.78
        var halo := MeshInstance3D.new()
        halo.mesh = halo_mesh
        halo.material_override = _make_material(Color("ba63ff"), 2.2)
        halo.rotation_degrees.x = 90.0
        shard.add_child(halo)

        shard.body_entered.connect(_on_shard_body_entered.bind(shard))
        shard_nodes.append(shard)


func _spawn_hazards() -> void:
    var hazard_data := [
        [Vector3(0.0, 0.65, 5.0), Vector3(1.0, 0.0, 0.0), 8.5, 1.25, 0.0],
        [Vector3(4.0, 0.65, 0.0), Vector3(0.0, 0.0, 1.0), 8.0, 1.5, 1.7],
        [Vector3(-4.0, 0.65, -5.0), Vector3(1.0, 0.0, 0.0), 7.0, 1.8, 3.4],
    ]

    for index in hazard_data.size():
        var data = hazard_data[index]
        var hazard := Area3D.new()
        hazard.name = "EnergyBarrier%02d" % (index + 1)
        hazard.position = data[0]
        hazard.set_meta("origin", data[0])
        hazard.set_meta("axis", data[1])
        hazard.set_meta("span", data[2])
        hazard.set_meta("speed", data[3])
        hazard.set_meta("phase", data[4])
        add_child(hazard)

        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(2.8, 1.2, 0.8)
        collision.shape = shape
        hazard.add_child(collision)

        _add_box_visual(hazard, Vector3(2.8, 1.2, 0.8), Vector3.ZERO, Color("ff3d91"), 2.8)
        _add_box_visual(hazard, Vector3(3.2, 0.12, 1.1), Vector3(0.0, 0.55, 0.0), Color("ffd5f0"), 2.0)

        hazard.body_entered.connect(_on_hazard_body_entered)
        hazard_nodes.append(hazard)


func _spawn_portal() -> void:
    portal = Area3D.new()
    portal.name = "ExitPortal"
    portal.position = Vector3(10.0, 1.8, -10.0)
    add_child(portal)

    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 1.55
    collision.shape = shape
    portal.add_child(collision)

    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 1.08
    ring_mesh.outer_radius = 1.38
    portal_ring = MeshInstance3D.new()
    portal_ring.mesh = ring_mesh
    portal_ring.rotation_degrees.x = 90.0
    portal_material = _make_material(Color("ff4f9f"), 2.4)
    portal_ring.material_override = portal_material
    portal.add_child(portal_ring)

    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.95
    core_mesh.height = 1.9
    var core := MeshInstance3D.new()
    core.name = "PortalCore"
    core.mesh = core_mesh
    core.scale.z = 0.16
    core.material_override = _make_material(Color(0.5, 0.15, 0.7, 0.4), 1.1, true)
    portal.add_child(core)

    portal.body_entered.connect(_on_portal_body_entered)


func _build_interface() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "Interface"
    add_child(canvas)

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    canvas.add_child(root)

    var top_bar := ColorRect.new()
    top_bar.color = Color(0.02, 0.035, 0.12, 0.82)
    top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top_bar.offset_bottom = 76.0
    top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(top_bar)

    var title := Label.new()
    title.text = "AURORA DRIFT 3D"
    title.position = Vector2(26.0, 13.0)
    title.add_theme_font_size_override("font_size", 26)
    title.add_theme_color_override("font_color", Color("79ffe9"))
    top_bar.add_child(title)

    score_label = Label.new()
    score_label.position = Vector2(28.0, 45.0)
    score_label.add_theme_font_size_override("font_size", 18)
    score_label.add_theme_color_override("font_color", Color("f3edff"))
    top_bar.add_child(score_label)

    timer_label = Label.new()
    timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    timer_label.anchor_left = 1.0
    timer_label.anchor_right = 1.0
    timer_label.offset_left = -260.0
    timer_label.offset_right = -28.0
    timer_label.offset_top = 22.0
    timer_label.offset_bottom = 58.0
    timer_label.add_theme_font_size_override("font_size", 23)
    timer_label.add_theme_color_override("font_color", Color("c6b8ff"))
    top_bar.add_child(timer_label)

    message_label = Label.new()
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    message_label.anchor_left = 0.5
    message_label.anchor_right = 0.5
    message_label.offset_left = -320.0
    message_label.offset_right = 320.0
    message_label.offset_top = 92.0
    message_label.offset_bottom = 142.0
    message_label.add_theme_font_size_override("font_size", 25)
    message_label.add_theme_color_override("font_color", Color("ffffff"))
    message_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.0, 0.3, 0.9))
    message_label.add_theme_constant_override("shadow_offset_x", 3)
    message_label.add_theme_constant_override("shadow_offset_y", 3)
    root.add_child(message_label)

    var hint := Label.new()
    hint.text = "WASD / ARROWS TO MOVE  •  SPACE TO JUMP  •  R TO RESTART"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.anchor_left = 0.5
    hint.anchor_right = 0.5
    hint.anchor_top = 1.0
    hint.anchor_bottom = 1.0
    hint.offset_left = -350.0
    hint.offset_right = 350.0
    hint.offset_top = -34.0
    hint.offset_bottom = -8.0
    hint.add_theme_font_size_override("font_size", 14)
    hint.add_theme_color_override("font_color", Color(0.76, 0.82, 1.0, 0.75))
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(hint)

    _create_direction_button(root, "◀", Vector2(26.0, -118.0), "left")
    _create_direction_button(root, "▶", Vector2(178.0, -118.0), "right")
    _create_direction_button(root, "▲", Vector2(102.0, -194.0), "forward")
    _create_direction_button(root, "▼", Vector2(102.0, -42.0), "back")

    var jump_button := _create_action_button(root, "JUMP", Vector2(-158.0, -142.0), Vector2(128.0, 96.0), true)
    jump_button.button_down.connect(_on_jump_pressed)

    victory_panel = PanelContainer.new()
    victory_panel.visible = false
    victory_panel.anchor_left = 0.5
    victory_panel.anchor_right = 0.5
    victory_panel.anchor_top = 0.5
    victory_panel.anchor_bottom = 0.5
    victory_panel.offset_left = -245.0
    victory_panel.offset_right = 245.0
    victory_panel.offset_top = -150.0
    victory_panel.offset_bottom = 150.0
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.025, 0.04, 0.16, 0.96)
    panel_style.border_color = Color("55f4d9")
    panel_style.set_border_width_all(3)
    panel_style.set_corner_radius_all(24)
    panel_style.content_margin_left = 35.0
    panel_style.content_margin_right = 35.0
    panel_style.content_margin_top = 28.0
    panel_style.content_margin_bottom = 28.0
    victory_panel.add_theme_stylebox_override("panel", panel_style)
    root.add_child(victory_panel)

    var victory_box := VBoxContainer.new()
    victory_box.alignment = BoxContainer.ALIGNMENT_CENTER
    victory_panel.add_child(victory_box)

    var victory_title := Label.new()
    victory_title.text = "PORTAL STABILIZED!"
    victory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    victory_title.add_theme_font_size_override("font_size", 34)
    victory_title.add_theme_color_override("font_color", Color("6effe5"))
    victory_box.add_child(victory_title)

    victory_time_label = Label.new()
    victory_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    victory_time_label.add_theme_font_size_override("font_size", 22)
    victory_time_label.add_theme_color_override("font_color", Color("e8e4ff"))
    victory_box.add_child(victory_time_label)

    var spacer := Control.new()
    spacer.custom_minimum_size.y = 22.0
    victory_box.add_child(spacer)

    var restart_button := Button.new()
    restart_button.text = "PLAY AGAIN"
    restart_button.custom_minimum_size = Vector2(240.0, 58.0)
    restart_button.add_theme_font_size_override("font_size", 20)
    _style_button(restart_button, Color("6039aa"))
    restart_button.pressed.connect(func() -> void: get_tree().reload_current_scene())
    victory_box.add_child(restart_button)


func _create_direction_button(parent: Control, text: String, offset: Vector2, action: String) -> void:
    var button := _create_action_button(parent, text, offset, Vector2(70.0, 70.0), false)
    button.button_down.connect(_on_touch_action.bind(action, true))
    button.button_up.connect(_on_touch_action.bind(action, false))


func _create_action_button(parent: Control, text: String, offset: Vector2, size: Vector2, from_right: bool) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.anchor_top = 1.0
    button.anchor_bottom = 1.0
    if from_right:
        button.anchor_left = 1.0
        button.anchor_right = 1.0
    button.offset_left = offset.x
    button.offset_top = offset.y
    button.offset_right = offset.x + size.x
    button.offset_bottom = offset.y + size.y
    button.add_theme_font_size_override("font_size", 22)
    _style_button(button, Color(0.16, 0.28, 0.65, 0.72))
    parent.add_child(button)
    return button


func _style_button(button: Button, color: Color) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = color
    normal.border_color = Color(0.38, 0.95, 0.88, 0.9)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(18)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.3, 0.85, 0.75, 0.88)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = color.lightened(0.16)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("focus", hover)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color("081130"))


func _on_touch_action(action: String, pressed: bool) -> void:
    touch_actions[action] = pressed


func _on_jump_pressed() -> void:
    jump_requested = true


func _on_shard_body_entered(body: Node3D, shard: Area3D) -> void:
    if body != player or not shard.monitoring:
        return
    shard.set_deferred("monitoring", false)
    shard.visible = false
    collected += 1
    _update_hud()
    if collected >= TOTAL_SHARDS:
        portal_material.albedo_color = Color("43ffd1")
        portal_material.emission = Color("43ffd1")
        portal_material.emission_energy_multiplier = 4.0
        _show_message("ALL SHARDS FOUND — PORTAL OPEN!", 4.0)
    else:
        _show_message("SHARD %d / %d" % [collected, TOTAL_SHARDS], 1.25)


func _on_hazard_body_entered(body: Node3D) -> void:
    if body == player and hit_cooldown <= 0.0 and not won:
        _reset_player("ENERGY BARRIER — TRY AGAIN")


func _on_portal_body_entered(body: Node3D) -> void:
    if body != player or won:
        return
    if collected < TOTAL_SHARDS:
        _show_message("PORTAL LOCKED — %d SHARDS REMAIN" % (TOTAL_SHARDS - collected), 2.2)
        return
    won = true
    player.velocity = Vector3.ZERO
    victory_time_label.text = "All shards collected in %s" % _format_time(elapsed)
    victory_panel.visible = true
    _show_message("AURORA RUN COMPLETE", 5.0)


func _reset_player(reason: String) -> void:
    hit_cooldown = 1.0
    player.global_position = spawn_point
    player.velocity = Vector3.ZERO
    _show_message(reason, 1.8)


func _animate_world(delta: float) -> void:
    var time := Time.get_ticks_msec() / 1000.0
    for shard in shard_nodes:
        if is_instance_valid(shard) and shard.visible:
            shard.rotation.y += 1.8 * delta
            shard.position.y = float(shard.get_meta("base_y")) + sin(time * 2.2 + float(shard.get_meta("phase"))) * 0.22

    for hazard in hazard_nodes:
        var origin: Vector3 = hazard.get_meta("origin")
        var axis: Vector3 = hazard.get_meta("axis")
        var span: float = hazard.get_meta("span")
        var speed: float = hazard.get_meta("speed")
        var phase: float = hazard.get_meta("phase")
        hazard.position = origin + axis * sin(time * speed + phase) * span
        hazard.rotation.y += 0.35 * delta

    if is_instance_valid(portal_ring):
        portal_ring.rotation.z += (1.7 if collected >= TOTAL_SHARDS else 0.65) * delta
        portal.scale = Vector3.ONE * (1.0 + sin(time * 3.0) * 0.04)

    if is_instance_valid(player_visual):
        player_visual.position.y = sin(time * 5.0) * 0.05


func _update_camera(delta: float) -> void:
    if not is_instance_valid(camera) or not is_instance_valid(player):
        return
    var desired_position := player.global_position + Vector3(0.0, 9.0, 11.0)
    var weight := 1.0 - exp(-4.2 * delta)
    camera.global_position = camera.global_position.lerp(desired_position, weight)
    camera.look_at(player.global_position + Vector3(0.0, 0.7, 0.0), Vector3.UP)


func _update_hud() -> void:
    if is_instance_valid(score_label):
        score_label.text = "AURORA SHARDS  %02d / %02d" % [collected, TOTAL_SHARDS]
    if is_instance_valid(timer_label):
        timer_label.text = _format_time(elapsed)


func _show_message(text: String, duration: float) -> void:
    if not is_instance_valid(message_label):
        return
    message_label.text = text
    message_until = Time.get_ticks_msec() / 1000.0 + duration


func _format_time(value: float) -> String:
    var total_seconds := int(value)
    var minutes := total_seconds / 60
    var seconds := total_seconds % 60
    var hundredths := int(fmod(value, 1.0) * 100.0)
    return "%02d:%02d.%02d" % [minutes, seconds, hundredths]


func _add_static_box(parent: Node3D, size: Vector3, position: Vector3, color: Color, emission: float) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = position
    parent.add_child(body)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)

    _add_box_visual(body, size, Vector3.ZERO, color, emission)
    return body


func _add_box_visual(parent: Node3D, size: Vector3, position: Vector3, color: Color, emission: float) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.position = position
    visual.material_override = _make_material(color, emission)
    parent.add_child(visual)
    return visual


func _make_material(color: Color, emission_strength: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.38
    material.roughness = 0.32
    if emission_strength > 0.0:
        material.emission_enabled = true
        material.emission = Color(color.r, color.g, color.b, 1.0)
        material.emission_energy_multiplier = emission_strength
    if transparent or color.a < 1.0:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return material

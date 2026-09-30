extends Node3D

const PLAYER_CONTROLLER := preload("res://scripts/player.gd")
const ORBIT_CAMERA := preload("res://scripts/orbit_camera.gd")
const SHARD_MODEL := preload("res://models/aurora_shard.glb")
const SENTINEL_MODEL := preload("res://models/energy_sentinel.glb")
const PORTAL_MODEL := preload("res://models/exit_portal.glb")
const JUMP_PAD_MODEL := preload("res://models/jump_pad.glb")
const PLATFORM_MODEL := preload("res://models/moving_platform.glb")
const BEACON_MODEL := preload("res://models/switch_beacon.glb")

const LEVEL_COUNT := 4

var player: CharacterBody3D
var orbit_camera: Camera3D
var level_root: Node3D
var cosmos_root: Node3D
var world_environment: WorldEnvironment
var environment: Environment
var sky_material: ProceduralSkyMaterial
var sun: DirectionalLight3D
var accent_light: OmniLight3D

var current_level := 0
var level_name := ""
var level_mechanic := ""
var spawn_point := Vector3.ZERO
var required_shards := 0
var collected_shards := 0
var required_beacons := 0
var activated_beacons := 0
var level_elapsed := 0.0
var campaign_elapsed := 0.0
var time_limit := 0.0
var deaths := 0
var level_active := false
var hit_cooldown := 0.0
var message_until := 0.0

var shards: Array[Area3D] = []
var moving_hazards: Array[Area3D] = []
var moving_platforms: Array[AnimatableBody3D] = []
var rotating_lasers: Array[Node3D] = []
var vanishing_platforms: Array[StaticBody3D] = []
var wind_zones: Array[Dictionary] = []
var portal: Area3D
var portal_aura: MeshInstance3D
var portal_light: OmniLight3D

var hud_level: Label
var hud_objective: Label
var hud_time: Label
var hud_deaths: Label
var message_label: Label
var overlay_panel: PanelContainer
var overlay_title: Label
var overlay_body: Label
var overlay_button: Button
var overlay_mode := "intro"

var touch_state := {"left": false, "right": false, "forward": false, "back": false}


func _ready() -> void:
    _setup_input_actions()
    _build_environment()
    _spawn_player_and_camera()
    _build_interface()
    _load_level(0)


func _process(delta: float) -> void:
    hit_cooldown = maxf(0.0, hit_cooldown - delta)

    if level_active:
        level_elapsed += delta
        campaign_elapsed += delta
        if time_limit > 0.0 and level_elapsed >= time_limit:
            level_active = false
            _show_message("TIME FRACTURE — LEVEL RESTARTED", 2.5)
            call_deferred("_load_level", current_level)
            return

    _animate_collectibles(delta)
    _update_hud()

    if message_until > 0.0 and Time.get_ticks_msec() / 1000.0 > message_until:
        message_until = 0.0
        message_label.text = ""


func _physics_process(delta: float) -> void:
    _move_dynamic_obstacles()
    _update_vanishing_platforms()
    _apply_wind(delta)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("restart"):
        _load_level(current_level)


func _setup_input_actions() -> void:
    _ensure_key_action("move_left", [KEY_A, KEY_LEFT])
    _ensure_key_action("move_right", [KEY_D, KEY_RIGHT])
    _ensure_key_action("move_forward", [KEY_W, KEY_UP])
    _ensure_key_action("move_back", [KEY_S, KEY_DOWN])
    _ensure_key_action("jump", [KEY_SPACE])
    _ensure_key_action("restart", [KEY_R])
    _ensure_key_action("camera_left", [KEY_Q])
    _ensure_key_action("camera_right", [KEY_E])


func _ensure_key_action(action: StringName, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if not InputMap.action_get_events(action).is_empty():
        return
    for key_code in keys:
        var event := InputEventKey.new()
        event.physical_keycode = key_code
        InputMap.action_add_event(action, event)


func _build_environment() -> void:
    world_environment = WorldEnvironment.new()
    environment = Environment.new()
    sky_material = ProceduralSkyMaterial.new()
    var sky := Sky.new()
    sky.sky_material = sky_material
    environment.sky = sky
    environment.background_mode = Environment.BG_SKY
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.72
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_density = 0.008
    environment.fog_sky_affect = 0.35
    world_environment.environment = environment
    add_child(world_environment)

    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
    sun.light_energy = 1.4
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 45.0
    add_child(sun)

    accent_light = OmniLight3D.new()
    accent_light.position = Vector3(0.0, 10.0, 0.0)
    accent_light.omni_range = 38.0
    accent_light.light_energy = 4.5
    add_child(accent_light)

    cosmos_root = Node3D.new()
    cosmos_root.name = "CosmosBackdrop"
    add_child(cosmos_root)


func _spawn_player_and_camera() -> void:
    player = PLAYER_CONTROLLER.new()
    add_child(player)
    player.fell_into_void.connect(_on_player_fell)

    orbit_camera = ORBIT_CAMERA.new()
    add_child(orbit_camera)
    orbit_camera.set_target(player, true)
    player.set_camera(orbit_camera)


func _load_level(index: int) -> void:
    current_level = clampi(index, 0, LEVEL_COUNT - 1)
    level_active = false
    level_elapsed = 0.0
    hit_cooldown = 0.75
    collected_shards = 0
    activated_beacons = 0
    required_beacons = 0
    time_limit = 0.0

    shards.clear()
    moving_hazards.clear()
    moving_platforms.clear()
    rotating_lasers.clear()
    vanishing_platforms.clear()
    wind_zones.clear()
    portal = null
    portal_aura = null
    portal_light = null

    if is_instance_valid(level_root):
        remove_child(level_root)
        level_root.queue_free()
    level_root = Node3D.new()
    level_root.name = "Level%02d" % (current_level + 1)
    add_child(level_root)

    match current_level:
        0:
            _build_level_aurora_garden()
        1:
            _build_level_shifting_isles()
        2:
            _build_level_polarity_reactor()
        3:
            _build_level_event_horizon()

    player.set_gravity_multiplier(0.55 if current_level == 3 else 1.0)
    player.reset_to(spawn_point)
    player.set_controls_enabled(false)
    orbit_camera.reset_view(0.0, 36.0, 12.5)
    orbit_camera.set_target(player, true)
    _sync_touch_input()
    _update_portal_state()
    _show_level_intro()
    _update_hud()


func _build_level_aurora_garden() -> void:
    level_name = "AURORA GARDEN"
    level_mechanic = "Learn to pilot the drone. Collect every shard, avoid the sentinels, then enter the portal."
    required_shards = 6
    spawn_point = Vector3(-10.0, 1.1, 10.0)
    _apply_palette(Color("050a25"), Color("3348a0"), Color("42f5d4"), Color("9c62ff"))

    _add_static_platform(Vector3(0.0, -0.5, 0.0), Vector3(28.0, 1.0, 28.0), Color("102153"), false)
    _add_edge_rails(14.0, 14.0, 0.0)
    _add_pylons(13.0, 0.0, Color("42f5d4"))

    for position in [
        Vector3(-10, 1.1, 5), Vector3(-6, 1.1, -2), Vector3(-10, 1.1, -9),
        Vector3(0, 1.1, -8), Vector3(8, 1.1, -3), Vector3(8, 1.1, 8),
    ]:
        _add_shard(position)

    _add_moving_sentinel(Vector3(0, 0.9, 5), Vector3.RIGHT, 8.5, 1.15, 0.0)
    _add_moving_sentinel(Vector3(4, 0.9, -3), Vector3.FORWARD, 7.0, 1.45, 1.8)
    _add_portal(Vector3(11.0, 1.8, -11.0))


func _build_level_shifting_isles() -> void:
    level_name = "SHIFTING ISLES"
    level_mechanic = "Platforms now move above the void. Use cyan launch pads and rotate the camera to line up each jump."
    required_shards = 8
    spawn_point = Vector3(0.0, 1.2, 11.0)
    _apply_palette(Color("07112b"), Color("245d86"), Color("48d9ff"), Color("5ff2b9"))

    _add_static_platform(Vector3(0, -0.4, 11), Vector3(8, 0.8, 6), Color("123c66"), true)
    _add_static_platform(Vector3(-5, 1.0, 4), Vector3(6, 0.8, 5), Color("164b75"), true)
    _add_static_platform(Vector3(4, 2.0, 0), Vector3(6, 0.8, 6), Color("164b75"), true)
    _add_static_platform(Vector3(-3, 2.9, -6), Vector3(7, 0.8, 5), Color("164b75"), true)
    _add_static_platform(Vector3(6, 3.8, -11), Vector3(8, 0.8, 7), Color("123c66"), true)

    _add_moving_platform(Vector3(4.5, 0.2, 7.0), Vector3(4.2, 0.6, 4.2), Vector3.RIGHT, 2.8, 1.0, 0.0)
    _add_moving_platform(Vector3(-0.5, 1.8, -1.5), Vector3(4.2, 0.6, 4.2), Vector3.FORWARD, 2.4, 1.25, 1.4)
    _add_moving_platform(Vector3(2.0, 3.25, -8.5), Vector3(4.2, 0.6, 4.2), Vector3.RIGHT, 2.7, 1.4, 2.7)

    _add_jump_pad(Vector3(0, 0.06, 8.7), 12.5, 4.5)
    _add_jump_pad(Vector3(-5, 1.46, 2.8), 13.0, 4.0)
    _add_jump_pad(Vector3(-3, 3.36, -7.4), 13.5, 4.2)

    for position in [
        Vector3(-2.2, 1.1, 11), Vector3(2.2, 1.1, 11),
        Vector3(-6.2, 2.5, 4), Vector3(-3.8, 2.5, 4),
        Vector3(4, 3.5, 1.5), Vector3(4, 3.5, -1.5),
        Vector3(-3, 4.4, -6), Vector3(6, 5.3, -11),
    ]:
        _add_shard(position)

    _add_moving_sentinel(Vector3(4, 3.25, 0), Vector3.RIGHT, 1.8, 2.0, 0.2)
    _add_moving_sentinel(Vector3(6, 5.05, -11), Vector3.FORWARD, 2.1, 2.3, 2.0)
    _add_portal(Vector3(6.0, 6.0, -12.0))


func _build_level_polarity_reactor() -> void:
    level_name = "POLARITY REACTOR"
    level_mechanic = "Activate all 3 polarity beacons. Wind tunnels push the drone while rotating laser arms guard the shards."
    required_shards = 9
    required_beacons = 3
    spawn_point = Vector3(0.0, 1.1, 11.0)
    _apply_palette(Color("12051f"), Color("622466"), Color("ff4fc8"), Color("54e8ff"))

    _add_static_platform(Vector3(0, -0.5, 0), Vector3(30, 1, 30), Color("32174c"), false)
    _add_edge_rails(15.0, 15.0, 0.0)
    _add_pylons(14.0, 0.0, Color("ff4fc8"))

    _add_beacon(Vector3(-11, 0.02, -10))
    _add_beacon(Vector3(11, 0.02, -9))
    _add_beacon(Vector3(-10, 0.02, 10))

    _add_rotating_laser(Vector3(0, 0, 0), 8.0, 1.15)
    _add_rotating_laser(Vector3(7, 0, 7), 5.0, -1.7)
    _add_rotating_laser(Vector3(-7, 0, -5), 4.5, 2.1)

    _add_wind_zone(Vector3(-6, 1.2, 2), Vector3(5, 2.5, 10), Vector3(8, 0, 0), Color("4fdcff"))
    _add_wind_zone(Vector3(7, 1.2, -4), Vector3(5, 2.5, 9), Vector3(-7, 0, 3), Color("ff55ce"))

    for position in [
        Vector3(-12, 1.1, 2), Vector3(-7, 1.1, 0), Vector3(-2, 1.1, -10),
        Vector3(3, 1.1, -7), Vector3(9, 1.1, -2), Vector3(12, 1.1, 5),
        Vector3(5, 1.1, 11), Vector3(-3, 1.1, 8), Vector3(0, 1.1, 2),
    ]:
        _add_shard(position)

    _add_portal(Vector3(12.0, 1.8, 12.0))


func _build_level_event_horizon() -> void:
    level_name = "EVENT HORIZON"
    level_mechanic = "Low gravity, disappearing platforms, faster lasers, and a 105 second stability window. Keep moving."
    required_shards = 10
    required_beacons = 2
    time_limit = 105.0
    spawn_point = Vector3(0.0, 1.2, 12.0)
    _apply_palette(Color("02030c"), Color("30205e"), Color("ff3c76"), Color("765cff"))

    _add_static_platform(Vector3(0, -0.4, 12), Vector3(8, 0.8, 6), Color("25154f"), true)
    _add_static_platform(Vector3(-9, 0.8, 5), Vector3(6, 0.8, 6), Color("30185a"), true)
    _add_static_platform(Vector3(9, 1.4, 4), Vector3(6, 0.8, 6), Color("30185a"), true)
    _add_static_platform(Vector3(-7, 2.2, -7), Vector3(7, 0.8, 6), Color("30185a"), true)
    _add_static_platform(Vector3(7, 3.0, -9), Vector3(8, 0.8, 7), Color("25154f"), true)

    _add_vanishing_platform(Vector3(-4.5, 0.2, 9), 0.0)
    _add_vanishing_platform(Vector3(0, 0.65, 6), 1.2)
    _add_vanishing_platform(Vector3(4.8, 1.0, 7), 2.4)
    _add_vanishing_platform(Vector3(4.5, 1.7, 0), 0.8)
    _add_vanishing_platform(Vector3(0, 2.0, -3), 2.0)
    _add_vanishing_platform(Vector3(-3.5, 2.2, -5), 3.0)
    _add_vanishing_platform(Vector3(1, 2.8, -8), 1.5)

    _add_jump_pad(Vector3(0, 0.06, 10), 11.0, 6.0)
    _add_jump_pad(Vector3(-9, 1.26, 3.5), 12.0, 5.0)
    _add_jump_pad(Vector3(-7, 2.66, -8), 12.5, 5.5)

    _add_beacon(Vector3(-9, 1.22, 5))
    _add_beacon(Vector3(7, 3.42, -9))
    _add_rotating_laser(Vector3(-9, 1.2, 5), 4.8, 2.5)
    _add_rotating_laser(Vector3(7, 3.4, -9), 5.8, -3.0)
    _add_moving_sentinel(Vector3(9, 2.35, 4), Vector3.RIGHT, 2.2, 2.8, 0.3)
    _add_moving_sentinel(Vector3(-7, 3.15, -7), Vector3.FORWARD, 2.0, 3.1, 1.7)

    for position in [
        Vector3(-2, 1.1, 12), Vector3(2, 1.1, 12),
        Vector3(-9, 2.3, 6), Vector3(-9, 2.3, 3),
        Vector3(9, 2.9, 5), Vector3(9, 2.9, 2),
        Vector3(-7, 3.7, -6), Vector3(-7, 3.7, -9),
        Vector3(7, 4.5, -7), Vector3(7, 4.5, -11),
    ]:
        _add_shard(position)

    _add_portal(Vector3(7.0, 5.2, -10.0))


func _apply_palette(background: Color, horizon: Color, accent: Color, secondary: Color) -> void:
    sky_material.sky_top_color = background
    sky_material.sky_horizon_color = horizon
    sky_material.ground_bottom_color = background.darkened(0.35)
    sky_material.ground_horizon_color = horizon.darkened(0.42)
    sun.light_color = Color(background).lerp(Color.WHITE, 0.72)
    accent_light.light_color = accent
    environment.fog_light_color = horizon
    _rebuild_cosmos(accent, secondary)


func _rebuild_cosmos(accent: Color, secondary: Color) -> void:
    for child in cosmos_root.get_children():
        child.queue_free()

    var star_mesh := SphereMesh.new()
    star_mesh.radius = 0.055
    star_mesh.height = 0.11
    star_mesh.material = _make_material(Color("d9f7ff"), 3.0, true)
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.instance_count = 90
    multimesh.mesh = star_mesh
    var random := RandomNumberGenerator.new()
    random.seed = 4321 + current_level * 977
    for index in multimesh.instance_count:
        var position := Vector3(random.randf_range(-42, 42), random.randf_range(5, 32), random.randf_range(-42, 42))
        var scale := random.randf_range(0.5, 1.7)
        multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * scale), position))
    var stars := MultiMeshInstance3D.new()
    stars.multimesh = multimesh
    cosmos_root.add_child(stars)

    for ribbon_index in 3:
        var mesh := ImmediateMesh.new()
        mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
        for point in 33:
            var ratio := float(point) / 32.0
            var x := lerpf(-32.0, 32.0, ratio)
            var wave := sin(ratio * 10.0 + ribbon_index * 1.8) * (1.6 + ribbon_index * 0.4)
            var z := -25.0 + ribbon_index * 7.0
            var y := 13.0 + ribbon_index * 3.2 + wave
            mesh.surface_set_color(Color(accent if ribbon_index % 2 == 0 else secondary, 0.22))
            mesh.surface_add_vertex(Vector3(x, y - 0.75, z))
            mesh.surface_set_color(Color(secondary if ribbon_index % 2 == 0 else accent, 0.05))
            mesh.surface_add_vertex(Vector3(x, y + 0.75, z))
        mesh.surface_end()
        var ribbon := MeshInstance3D.new()
        ribbon.mesh = mesh
        ribbon.material_override = _make_material(Color(accent, 0.2), 1.5, true, true)
        cosmos_root.add_child(ribbon)


func _add_static_platform(position: Vector3, size: Vector3, color: Color, use_model: bool) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = position
    level_root.add_child(body)
    _add_box_collision(body, size)

    if use_model:
        var model := PLATFORM_MODEL.instantiate()
        model.scale = Vector3(size.x / 3.8, size.y / 0.44, size.z / 3.8)
        body.add_child(model)
    else:
        _add_box_visual(body, size, Vector3.ZERO, color, 0.08)
        _add_box_visual(body, Vector3(size.x * 0.93, 0.06, size.z * 0.93), Vector3(0, size.y * 0.5 + 0.035, 0), color.lightened(0.16), 0.45)
        _add_platform_trim(body, size, color.lightened(0.5))
    return body


func _add_moving_platform(origin: Vector3, size: Vector3, axis: Vector3, span: float, speed: float, phase: float) -> void:
    var body := AnimatableBody3D.new()
    body.position = origin
    body.sync_to_physics = true
    body.set_meta("origin", origin)
    body.set_meta("axis", axis.normalized())
    body.set_meta("span", span)
    body.set_meta("speed", speed)
    body.set_meta("phase", phase)
    level_root.add_child(body)
    _add_box_collision(body, size)
    var model := PLATFORM_MODEL.instantiate()
    model.scale = Vector3(size.x / 3.8, size.y / 0.44, size.z / 3.8)
    body.add_child(model)
    moving_platforms.append(body)


func _add_vanishing_platform(position: Vector3, phase: float) -> void:
    var body := StaticBody3D.new()
    body.position = position
    body.set_meta("phase", phase)
    body.set_meta("active", true)
    body.set_meta("collision", _add_box_collision(body, Vector3(4.0, 0.55, 4.0)))
    level_root.add_child(body)
    var model := PLATFORM_MODEL.instantiate()
    model.scale = Vector3(1.05, 1.1, 1.05)
    body.add_child(model)
    vanishing_platforms.append(body)


func _add_platform_trim(parent: Node3D, size: Vector3, color: Color) -> void:
    var y := size.y * 0.5 + 0.09
    _add_box_visual(parent, Vector3(size.x, 0.08, 0.08), Vector3(0, y, -size.z * 0.48), color, 1.7)
    _add_box_visual(parent, Vector3(size.x, 0.08, 0.08), Vector3(0, y, size.z * 0.48), color, 1.7)
    _add_box_visual(parent, Vector3(0.08, 0.08, size.z), Vector3(-size.x * 0.48, y, 0), color, 1.7)
    _add_box_visual(parent, Vector3(0.08, 0.08, size.z), Vector3(size.x * 0.48, y, 0), color, 1.7)


func _add_edge_rails(half_x: float, half_z: float, floor_y: float) -> void:
    var color := Color("54f8de")
    _add_static_platform(Vector3(0, floor_y + 0.65, -half_z), Vector3(half_x * 2.0, 1.3, 0.28), color, false)
    _add_static_platform(Vector3(0, floor_y + 0.65, half_z), Vector3(half_x * 2.0, 1.3, 0.28), color, false)
    _add_static_platform(Vector3(-half_x, floor_y + 0.65, 0), Vector3(0.28, 1.3, half_z * 2.0), color, false)
    _add_static_platform(Vector3(half_x, floor_y + 0.65, 0), Vector3(0.28, 1.3, half_z * 2.0), color, false)


func _add_pylons(edge: float, floor_y: float, color: Color) -> void:
    for x in [-edge, edge]:
        for z in [-edge, edge]:
            _add_box_visual(level_root, Vector3(0.7, 3.8, 0.7), Vector3(x, floor_y + 1.9, z), color.darkened(0.3), 0.8)
            var light := OmniLight3D.new()
            light.position = Vector3(x, floor_y + 4.0, z)
            light.light_color = color
            light.light_energy = 2.0
            light.omni_range = 7.0
            level_root.add_child(light)


func _add_shard(position: Vector3) -> void:
    var area := Area3D.new()
    area.position = position
    area.set_meta("base_y", position.y)
    area.set_meta("phase", shards.size() * 0.71)
    level_root.add_child(area)
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.85
    collision.shape = shape
    area.add_child(collision)
    var model := SHARD_MODEL.instantiate()
    model.scale = Vector3.ONE * 0.72
    area.add_child(model)
    area.body_entered.connect(_on_shard_collected.bind(area))
    shards.append(area)


func _add_moving_sentinel(origin: Vector3, axis: Vector3, span: float, speed: float, phase: float) -> void:
    var area := Area3D.new()
    area.position = origin
    area.set_meta("origin", origin)
    area.set_meta("axis", axis.normalized())
    area.set_meta("span", span)
    area.set_meta("speed", speed)
    area.set_meta("phase", phase)
    level_root.add_child(area)
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.9
    collision.shape = shape
    area.add_child(collision)
    var model := SENTINEL_MODEL.instantiate()
    model.scale = Vector3.ONE * 0.64
    area.add_child(model)
    area.body_entered.connect(_on_hazard_touched)
    moving_hazards.append(area)


func _add_rotating_laser(position: Vector3, length: float, speed: float) -> void:
    var pivot := Node3D.new()
    pivot.position = position
    pivot.set_meta("speed", speed)
    level_root.add_child(pivot)

    var center_model := SENTINEL_MODEL.instantiate()
    center_model.scale = Vector3.ONE * 0.55
    center_model.position.y = 0.85
    pivot.add_child(center_model)

    var beam := Area3D.new()
    beam.position = Vector3(length * 0.5, 0.78, 0)
    pivot.add_child(beam)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(length, 0.65, 0.45)
    collision.shape = shape
    beam.add_child(collision)
    _add_box_visual(beam, Vector3(length, 0.18, 0.28), Vector3.ZERO, Color("ff386f"), 4.0)
    beam.body_entered.connect(_on_hazard_touched)
    rotating_lasers.append(pivot)


func _add_jump_pad(position: Vector3, upward: float, forward: float) -> void:
    var area := Area3D.new()
    area.position = position
    area.set_meta("upward", upward)
    area.set_meta("forward", forward)
    level_root.add_child(area)
    var collision := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = 1.0
    shape.height = 0.35
    collision.shape = shape
    collision.position.y = 0.2
    area.add_child(collision)
    var model := JUMP_PAD_MODEL.instantiate()
    model.scale = Vector3.ONE * 0.8
    area.add_child(model)
    area.body_entered.connect(_on_jump_pad_touched.bind(area))


func _add_beacon(position: Vector3) -> void:
    var area := Area3D.new()
    area.position = position
    area.set_meta("activated", false)
    level_root.add_child(area)
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 1.05
    collision.shape = shape
    collision.position.y = 1.0
    area.add_child(collision)
    var model := BEACON_MODEL.instantiate()
    model.scale = Vector3.ONE * 0.85
    area.add_child(model)
    var light := OmniLight3D.new()
    light.name = "BeaconLight"
    light.position.y = 1.6
    light.light_color = Color("ff4cae")
    light.light_energy = 1.8
    light.omni_range = 6.0
    area.add_child(light)
    area.body_entered.connect(_on_beacon_touched.bind(area))


func _add_wind_zone(center: Vector3, size: Vector3, force: Vector3, color: Color) -> void:
    wind_zones.append({"center": center, "size": size, "force": force})
    var visual := Node3D.new()
    visual.position = center
    level_root.add_child(visual)
    _add_box_visual(visual, size, Vector3.ZERO, Color(color, 0.08), 0.7, true)
    for index in 5:
        var offset := lerpf(-size.z * 0.38, size.z * 0.38, float(index) / 4.0)
        _add_box_visual(visual, Vector3(size.x * 0.65, 0.05, 0.05), Vector3(0, 0.1 + index * 0.18, offset), Color(color, 0.55), 2.0, true)


func _add_portal(center: Vector3) -> void:
    portal = Area3D.new()
    portal.position = center
    level_root.add_child(portal)
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 1.55
    collision.shape = shape
    portal.add_child(collision)
    var model := PORTAL_MODEL.instantiate()
    model.scale = Vector3.ONE * 0.88
    portal.add_child(model)

    var aura_mesh := SphereMesh.new()
    aura_mesh.radius = 1.05
    aura_mesh.height = 2.1
    portal_aura = MeshInstance3D.new()
    portal_aura.mesh = aura_mesh
    portal_aura.scale.z = 0.13
    portal_aura.material_override = _make_material(Color(1.0, 0.15, 0.55, 0.28), 2.0, true, true)
    portal.add_child(portal_aura)

    portal_light = OmniLight3D.new()
    portal_light.light_color = Color("ff3d8d")
    portal_light.light_energy = 3.0
    portal_light.omni_range = 8.0
    portal.add_child(portal_light)
    portal.body_entered.connect(_on_portal_touched)


func _move_dynamic_obstacles() -> void:
    var time := Time.get_ticks_msec() / 1000.0
    for hazard in moving_hazards:
        if not is_instance_valid(hazard):
            continue
        var origin: Vector3 = hazard.get_meta("origin")
        var axis: Vector3 = hazard.get_meta("axis")
        hazard.position = origin + axis * sin(time * float(hazard.get_meta("speed")) + float(hazard.get_meta("phase"))) * float(hazard.get_meta("span"))
        hazard.rotation.y += 0.035
    for platform in moving_platforms:
        if not is_instance_valid(platform):
            continue
        var origin: Vector3 = platform.get_meta("origin")
        var axis: Vector3 = platform.get_meta("axis")
        platform.position = origin + axis * sin(time * float(platform.get_meta("speed")) + float(platform.get_meta("phase"))) * float(platform.get_meta("span"))
    for laser in rotating_lasers:
        if is_instance_valid(laser):
            laser.rotation.y += float(laser.get_meta("speed")) * get_physics_process_delta_time()


func _update_vanishing_platforms() -> void:
    if vanishing_platforms.is_empty():
        return
    var time := Time.get_ticks_msec() / 1000.0
    for body in vanishing_platforms:
        if not is_instance_valid(body):
            continue
        var phase := float(body.get_meta("phase"))
        var active := fmod(time + phase, 4.6) < 3.15
        if active != bool(body.get_meta("active")):
            body.set_meta("active", active)
            var collision: CollisionShape3D = body.get_meta("collision")
            collision.set_deferred("disabled", not active)
            body.visible = active


func _apply_wind(delta: float) -> void:
    if not level_active or not is_instance_valid(player):
        return
    for zone in wind_zones:
        var center: Vector3 = zone["center"]
        var half: Vector3 = zone["size"] * 0.5
        var local := player.global_position - center
        if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
            player.velocity += Vector3(zone["force"]) * delta


func _animate_collectibles(delta: float) -> void:
    var time := Time.get_ticks_msec() / 1000.0
    for shard in shards:
        if is_instance_valid(shard) and shard.visible:
            shard.rotation.y += 1.7 * delta
            shard.position.y = float(shard.get_meta("base_y")) + sin(time * 2.3 + float(shard.get_meta("phase"))) * 0.2
    if is_instance_valid(portal):
        portal.rotation.z += (1.15 if _requirements_met() else 0.35) * delta
        var pulse := 1.0 + sin(time * 3.2) * 0.035
        portal.scale = Vector3.ONE * pulse


func _on_shard_collected(body: Node3D, shard: Area3D) -> void:
    if body != player or not shard.monitoring or not level_active:
        return
    shard.set_deferred("monitoring", false)
    shard.visible = false
    collected_shards += 1
    _show_message("AURORA SHARD %d / %d" % [collected_shards, required_shards], 1.35)
    _update_portal_state()


func _on_hazard_touched(body: Node3D) -> void:
    if body == player and hit_cooldown <= 0.0 and level_active:
        _reset_player("ENERGY IMPACT — RECALIBRATED")


func _on_jump_pad_touched(body: Node3D, pad: Area3D) -> void:
    if body == player and level_active:
        player.launch(float(pad.get_meta("upward")), float(pad.get_meta("forward")))
        _show_message("LAUNCH BOOST", 0.8)


func _on_beacon_touched(body: Node3D, beacon: Area3D) -> void:
    if body != player or bool(beacon.get_meta("activated")) or not level_active:
        return
    beacon.set_meta("activated", true)
    activated_beacons += 1
    var light := beacon.get_node("BeaconLight") as OmniLight3D
    light.light_color = Color("55ffd9")
    light.light_energy = 4.5
    beacon.scale = Vector3.ONE * 1.12
    _show_message("POLARITY BEACON %d / %d" % [activated_beacons, required_beacons], 1.6)
    _update_portal_state()


func _on_portal_touched(body: Node3D) -> void:
    if body != player or not level_active:
        return
    if not _requirements_met():
        var parts: Array[String] = []
        if collected_shards < required_shards:
            parts.append("%d SHARDS" % (required_shards - collected_shards))
        if activated_beacons < required_beacons:
            parts.append("%d BEACONS" % (required_beacons - activated_beacons))
        _show_message("PORTAL LOCKED — " + " + ".join(parts), 2.2)
        return
    _complete_level()


func _on_player_fell() -> void:
    if hit_cooldown <= 0.0 and level_active:
        _reset_player("VOID RECOVERY")


func _reset_player(reason: String) -> void:
    deaths += 1
    hit_cooldown = 1.25
    player.reset_to(spawn_point)
    orbit_camera.set_target(player, true)
    _show_message(reason, 1.7)


func _requirements_met() -> bool:
    return collected_shards >= required_shards and activated_beacons >= required_beacons


func _update_portal_state() -> void:
    if not is_instance_valid(portal_light) or not is_instance_valid(portal_aura):
        return
    var open := _requirements_met()
    var color := Color("48ffe0") if open else Color("ff3d8d")
    portal_light.light_color = color
    portal_light.light_energy = 6.0 if open else 2.5
    var material := portal_aura.material_override as StandardMaterial3D
    material.albedo_color = Color(color, 0.34 if open else 0.2)
    material.emission = color
    material.emission_energy_multiplier = 5.0 if open else 1.6
    if open:
        _show_message("PORTAL STABILIZED — EXIT OPEN", 2.5)


func _complete_level() -> void:
    level_active = false
    player.set_controls_enabled(false)
    if current_level < LEVEL_COUNT - 1:
        overlay_mode = "next"
        overlay_title.text = "LEVEL %d COMPLETE" % (current_level + 1)
        overlay_body.text = "%s stabilized in %s\n\nNext: %s" % [level_name, _format_time(level_elapsed), _next_level_name()]
        overlay_button.text = "NEXT LEVEL"
    else:
        overlay_mode = "campaign"
        overlay_title.text = "AURORA RESTORED"
        overlay_body.text = "All four sectors stabilized.\nCampaign time: %s\nRecoveries: %d" % [_format_time(campaign_elapsed), deaths]
        overlay_button.text = "PLAY AGAIN"
    overlay_panel.visible = true


func _next_level_name() -> String:
    var names := ["SHIFTING ISLES", "POLARITY REACTOR", "EVENT HORIZON", "AURORA GARDEN"]
    return names[(current_level + 1) % names.size()]


func _show_level_intro() -> void:
    overlay_mode = "intro"
    overlay_title.text = "LEVEL %d — %s" % [current_level + 1, level_name]
    var extra := "\n\nTime limit: %d seconds" % int(time_limit) if time_limit > 0.0 else ""
    overlay_body.text = level_mechanic + extra + "\n\nSwipe the right side of the screen to rotate the camera."
    overlay_button.text = "START LEVEL"
    overlay_panel.visible = true


func _on_overlay_button_pressed() -> void:
    match overlay_mode:
        "intro":
            overlay_panel.visible = false
            level_active = true
            player.set_controls_enabled(true)
            _show_message("GO!", 1.0)
        "next":
            overlay_panel.visible = false
            _load_level(current_level + 1)
        "campaign":
            deaths = 0
            campaign_elapsed = 0.0
            overlay_panel.visible = false
            _load_level(0)


func _build_interface() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "Interface"
    add_child(canvas)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    canvas.add_child(root)

    var top_panel := PanelContainer.new()
    top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top_panel.offset_bottom = 92.0
    var top_style := StyleBoxFlat.new()
    top_style.bg_color = Color(0.01, 0.02, 0.09, 0.9)
    top_style.border_color = Color(0.2, 0.85, 0.9, 0.55)
    top_style.border_width_bottom = 2
    top_style.content_margin_left = 24.0
    top_style.content_margin_right = 24.0
    top_style.content_margin_top = 12.0
    top_style.content_margin_bottom = 10.0
    top_panel.add_theme_stylebox_override("panel", top_style)
    root.add_child(top_panel)

    var top_row := HBoxContainer.new()
    top_panel.add_child(top_row)
    var left_box := VBoxContainer.new()
    left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(left_box)
    hud_level = Label.new()
    hud_level.add_theme_font_size_override("font_size", 24)
    hud_level.add_theme_color_override("font_color", Color("72ffe7"))
    left_box.add_child(hud_level)
    hud_objective = Label.new()
    hud_objective.add_theme_font_size_override("font_size", 16)
    hud_objective.add_theme_color_override("font_color", Color("ddd9ff"))
    left_box.add_child(hud_objective)

    var right_box := VBoxContainer.new()
    right_box.custom_minimum_size.x = 250.0
    top_row.add_child(right_box)
    hud_time = Label.new()
    hud_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    hud_time.add_theme_font_size_override("font_size", 25)
    hud_time.add_theme_color_override("font_color", Color("c5b6ff"))
    right_box.add_child(hud_time)
    hud_deaths = Label.new()
    hud_deaths.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    hud_deaths.add_theme_font_size_override("font_size", 14)
    hud_deaths.add_theme_color_override("font_color", Color(0.75, 0.8, 1.0, 0.75))
    right_box.add_child(hud_deaths)

    message_label = Label.new()
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.anchor_left = 0.5
    message_label.anchor_right = 0.5
    message_label.offset_left = -360.0
    message_label.offset_right = 360.0
    message_label.offset_top = 108.0
    message_label.offset_bottom = 155.0
    message_label.add_theme_font_size_override("font_size", 23)
    message_label.add_theme_color_override("font_color", Color.WHITE)
    message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0.12, 0.95))
    message_label.add_theme_constant_override("shadow_offset_x", 3)
    message_label.add_theme_constant_override("shadow_offset_y", 3)
    message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(message_label)

    _create_direction_button(root, "◀", Vector2(26, -120), "left")
    _create_direction_button(root, "▶", Vector2(178, -120), "right")
    _create_direction_button(root, "▲", Vector2(102, -196), "forward")
    _create_direction_button(root, "▼", Vector2(102, -44), "back")

    var jump := _create_button(root, "JUMP", Vector2(-164, -145), Vector2(136, 102), true, Color(0.2, 0.55, 0.72, 0.78))
    jump.button_down.connect(func() -> void: player.request_jump())
    var camera_left := _create_button(root, "CAM ◀", Vector2(-326, -220), Vector2(116, 58), true, Color(0.28, 0.18, 0.55, 0.74))
    var camera_right := _create_button(root, "CAM ▶", Vector2(-198, -220), Vector2(116, 58), true, Color(0.28, 0.18, 0.55, 0.74))
    camera_left.button_down.connect(func() -> void: orbit_camera.set_button_axis(-1.0))
    camera_left.button_up.connect(func() -> void: orbit_camera.set_button_axis(0.0))
    camera_right.button_down.connect(func() -> void: orbit_camera.set_button_axis(1.0))
    camera_right.button_up.connect(func() -> void: orbit_camera.set_button_axis(0.0))

    var camera_hint := Label.new()
    camera_hint.text = "SWIPE RIGHT SIDE TO ORBIT CAMERA  •  Q / E  •  RIGHT-MOUSE DRAG"
    camera_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    camera_hint.anchor_left = 0.5
    camera_hint.anchor_right = 0.5
    camera_hint.anchor_top = 1.0
    camera_hint.anchor_bottom = 1.0
    camera_hint.offset_left = -360.0
    camera_hint.offset_right = 360.0
    camera_hint.offset_top = -30.0
    camera_hint.offset_bottom = -7.0
    camera_hint.add_theme_font_size_override("font_size", 13)
    camera_hint.add_theme_color_override("font_color", Color(0.72, 0.82, 1.0, 0.72))
    camera_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(camera_hint)

    overlay_panel = PanelContainer.new()
    overlay_panel.anchor_left = 0.5
    overlay_panel.anchor_right = 0.5
    overlay_panel.anchor_top = 0.5
    overlay_panel.anchor_bottom = 0.5
    overlay_panel.offset_left = -310.0
    overlay_panel.offset_right = 310.0
    overlay_panel.offset_top = -185.0
    overlay_panel.offset_bottom = 185.0
    var overlay_style := StyleBoxFlat.new()
    overlay_style.bg_color = Color(0.015, 0.025, 0.12, 0.97)
    overlay_style.border_color = Color("55efd7")
    overlay_style.set_border_width_all(3)
    overlay_style.set_corner_radius_all(26)
    overlay_style.content_margin_left = 42.0
    overlay_style.content_margin_right = 42.0
    overlay_style.content_margin_top = 32.0
    overlay_style.content_margin_bottom = 30.0
    overlay_panel.add_theme_stylebox_override("panel", overlay_style)
    root.add_child(overlay_panel)

    var overlay_box := VBoxContainer.new()
    overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
    overlay_panel.add_child(overlay_box)
    overlay_title = Label.new()
    overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_title.add_theme_font_size_override("font_size", 32)
    overlay_title.add_theme_color_override("font_color", Color("69ffe4"))
    overlay_box.add_child(overlay_title)
    overlay_body = Label.new()
    overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    overlay_body.custom_minimum_size = Vector2(520, 155)
    overlay_body.add_theme_font_size_override("font_size", 18)
    overlay_body.add_theme_color_override("font_color", Color("e5e3ff"))
    overlay_box.add_child(overlay_body)
    overlay_button = Button.new()
    overlay_button.text = "START"
    overlay_button.custom_minimum_size = Vector2(280, 62)
    overlay_button.add_theme_font_size_override("font_size", 21)
    _style_button(overlay_button, Color(0.22, 0.48, 0.65, 0.9))
    overlay_button.pressed.connect(_on_overlay_button_pressed)
    overlay_box.add_child(overlay_button)


func _create_direction_button(parent: Control, text: String, offset: Vector2, action: String) -> void:
    var button := _create_button(parent, text, offset, Vector2(70, 70), false, Color(0.12, 0.25, 0.58, 0.75))
    button.button_down.connect(_on_touch_action.bind(action, true))
    button.button_up.connect(_on_touch_action.bind(action, false))


func _create_button(parent: Control, text: String, offset: Vector2, size: Vector2, from_right: bool, color: Color) -> Button:
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
    button.add_theme_font_size_override("font_size", 20)
    _style_button(button, color)
    parent.add_child(button)
    return button


func _style_button(button: Button, color: Color) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = color
    normal.border_color = Color(0.4, 0.96, 0.9, 0.9)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(18)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = color.lightened(0.16)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.35, 0.9, 0.78, 0.92)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("focus", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color("07112b"))


func _on_touch_action(action: String, pressed: bool) -> void:
    touch_state[action] = pressed
    _sync_touch_input()


func _sync_touch_input() -> void:
    if not is_instance_valid(player):
        return
    var vector := Vector2(
        float(touch_state["right"]) - float(touch_state["left"]),
        float(touch_state["back"]) - float(touch_state["forward"])
    )
    player.set_touch_input(vector.normalized() if vector.length_squared() > 1.0 else vector)


func _update_hud() -> void:
    if not is_instance_valid(hud_level):
        return
    hud_level.text = "LEVEL %d/%d  •  %s" % [current_level + 1, LEVEL_COUNT, level_name]
    var beacon_text := "  •  BEACONS %d/%d" % [activated_beacons, required_beacons] if required_beacons > 0 else ""
    hud_objective.text = "SHARDS %d/%d%s" % [collected_shards, required_shards, beacon_text]
    if time_limit > 0.0:
        var remaining := maxf(0.0, time_limit - level_elapsed)
        hud_time.text = "T−" + _format_time(remaining)
        hud_time.add_theme_color_override("font_color", Color("ff5c83") if remaining < 20.0 else Color("c5b6ff"))
    else:
        hud_time.text = _format_time(level_elapsed)
    hud_deaths.text = "RECOVERIES  %02d" % deaths


func _show_message(text: String, duration: float) -> void:
    if not is_instance_valid(message_label):
        return
    message_label.text = text
    message_until = Time.get_ticks_msec() / 1000.0 + duration


func _format_time(value: float) -> String:
    var total_seconds := int(value)
    return "%02d:%02d.%02d" % [total_seconds / 60, total_seconds % 60, int(fmod(value, 1.0) * 100.0)]


func _add_box_collision(parent: CollisionObject3D, size: Vector3) -> CollisionShape3D:
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    parent.add_child(collision)
    return collision


func _add_box_visual(parent: Node3D, size: Vector3, position: Vector3, color: Color, emission: float = 0.0, transparent: bool = false) -> MeshInstance3D:
    var box := BoxMesh.new()
    box.size = size
    var visual := MeshInstance3D.new()
    visual.mesh = box
    visual.position = position
    visual.material_override = _make_material(color, emission, transparent, false)
    parent.add_child(visual)
    return visual


func _make_material(color: Color, emission: float = 0.0, transparent: bool = false, unshaded: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.38
    material.roughness = 0.28
    if emission > 0.0:
        material.emission_enabled = true
        material.emission = Color(color.r, color.g, color.b, 1.0)
        material.emission_energy_multiplier = emission
    if transparent or color.a < 1.0:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    if unshaded:
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.vertex_color_use_as_albedo = true
    return material

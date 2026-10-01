extends Node3D

const ARENA_SIZE := Vector2(72.0, 46.0)
const SPAWNS_ALPHA := [
    Vector3(-31.0, 0.05, -5.5), Vector3(-30.0, 0.05, -2.8),
    Vector3(-31.0, 0.05, 0.0), Vector3(-30.0, 0.05, 2.8), Vector3(-31.0, 0.05, 5.5),
]
const SPAWNS_BRAVO := [
    Vector3(31.0, 0.05, 5.5), Vector3(30.0, 0.05, 2.8),
    Vector3(31.0, 0.05, 0.0), Vector3(30.0, 0.05, -2.8), Vector3(31.0, 0.05, -5.5),
]

var obstacles: Array = []
var astar := AStar3D.new()
var material_cache: Dictionary = {}
var ambience: AudioStreamPlayer
var environment_model: Node3D

func _ready() -> void:
    name = "DockyardReforged"

func build() -> void:
    _define_layout()
    _build_world_environment()
    _build_floor_and_boundaries()
    _load_authored_environment()
    _build_collision_layout()
    _build_team_lights()
    _build_rain()
    _build_ambience()
    _build_navigation_graph()

func _define_layout() -> void:
    obstacles = [
        _obstacle(-25, -14, 8, 2.65, 2.8, "container"),
        _obstacle(-14, -14, 10, 2.65, 2.8, "container"),
        _obstacle(2, -14, 8, 2.65, 2.8, "container"),
        _obstacle(17, -14, 12, 2.65, 2.8, "container"),
        _obstacle(28, -8, 2.8, 2.65, 8, "container"),
        _obstacle(25, 14, 8, 2.65, 2.8, "container"),
        _obstacle(14, 14, 10, 2.65, 2.8, "container"),
        _obstacle(-2, 14, 8, 2.65, 2.8, "container"),
        _obstacle(-17, 14, 12, 2.65, 2.8, "container"),
        _obstacle(-28, 8, 2.8, 2.65, 8, "container"),
        _obstacle(0, 0, 13.5, 4.1, 8, "customs"),
        _obstacle(-25, -3, 3.2, 1.15, 0.85, "cover"),
        _obstacle(-17, 4, 2.3, 1.25, 1.15, "cover"),
        _obstacle(-10, -6, 2.3, 1.25, 1.15, "cover"),
        _obstacle(-9, 8, 3.2, 1.15, 0.85, "cover"),
        _obstacle(9, -8, 2.3, 1.25, 1.15, "cover"),
        _obstacle(10, 6, 2.3, 1.25, 1.15, "cover"),
        _obstacle(17, -4, 3.2, 1.15, 0.85, "cover"),
        _obstacle(25, 3, 2.3, 1.25, 1.15, "cover"),
        _obstacle(-4.8, -8, 2.3, 1.25, 1.15, "cover"),
        _obstacle(4.8, 8, 3.2, 1.15, 0.85, "cover"),
        _obstacle(-4.8, 8, 2.3, 1.25, 1.15, "cover"),
        _obstacle(4.8, -8, 2.3, 1.25, 1.15, "cover"),
    ]

func _obstacle(x: float, z: float, sx: float, sy: float, sz: float, kind: String) -> Dictionary:
    return {
        "position": Vector3(x, sy * 0.5, z),
        "size": Vector3(sx, sy, sz),
        "kind": kind,
    }

func _build_world_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("071420")
    sky_material.sky_horizon_color = Color("25485b")
    sky_material.ground_bottom_color = Color("03070b")
    sky_material.ground_horizon_color = Color("122733")
    sky_material.sun_angle_max = 5.0
    sky_material.sun_curve = 0.08
    var sky := Sky.new()
    sky.sky_material = sky_material
    env.sky = sky
    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_color = Color("8db4c4")
    env.ambient_light_energy = 0.72
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.adjustment_enabled = true
    env.adjustment_brightness = 1.02
    env.adjustment_contrast = 1.16
    env.adjustment_saturation = 0.88
    world.environment = env
    add_child(world)

    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-52, -28, 0)
    moon.light_color = Color("9ad7ee")
    moon.light_energy = 1.15
    moon.shadow_enabled = true
    moon.directional_shadow_max_distance = 42.0
    add_child(moon)

    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-24, 146, 0)
    fill.light_color = Color("ff9b63")
    fill.light_energy = 0.24
    fill.shadow_enabled = false
    add_child(fill)

func _build_floor_and_boundaries() -> void:
    _static_box(Vector3(0, -0.38, 0), Vector3(72, 0.75, 46), "Deck")
    _static_box(Vector3(0, 3.5, -22.2), Vector3(72, 7.0, 1.2), "NorthWarehouse")
    _static_box(Vector3(0, 3.5, 22.2), Vector3(72, 7.0, 1.2), "SouthWarehouse")
    _static_box(Vector3(-35.6, 2.0, 0), Vector3(0.8, 4.0, 46), "WestFence")
    _static_box(Vector3(35.6, 2.0, 0), Vector3(0.8, 4.0, 46), "EastFence")

func _load_authored_environment() -> void:
    if ResourceLoader.exists("res://models/dockyard_environment.glb"):
        environment_model = (load("res://models/dockyard_environment.glb") as PackedScene).instantiate()
        environment_model.name = "AuthoredBlenderEnvironment"
        add_child(environment_model)
    else:
        _build_fallback_visuals()

func _build_collision_layout() -> void:
    for index in obstacles.size():
        var data: Dictionary = obstacles[index]
        var body := _static_box(data["position"], data["size"], "TacticalCover_%02d" % index)
        body.set_meta("cover_kind", data["kind"])

func _build_fallback_visuals() -> void:
    _visual_box(Vector3(0, -0.37, 0), Vector3(72, 0.72, 46), Color("111d24"), 0.0)
    _visual_box(Vector3(0, 3.5, -22), Vector3(72, 7, 1.5), Color("15313b"), 0.0)
    _visual_box(Vector3(0, 3.5, 22), Vector3(72, 7, 1.5), Color("34221d"), 0.0)
    for data in obstacles:
        var kind: String = data["kind"]
        var color := Color("174858")
        if kind == "cover": color = Color("57432c")
        elif kind == "customs": color = Color("1b3543")
        _visual_box(data["position"], data["size"], color, 0.0)

func _build_team_lights() -> void:
    _add_team_light(Vector3(-28, 4.4, 0), Color("28cde0"))
    _add_team_light(Vector3(28, 4.4, 0), Color("ff7842"))
    for position in [Vector3(-8, 5.4, 10), Vector3(8, 5.4, -10)]:
        var light := OmniLight3D.new()
        light.position = position
        light.light_color = Color("70d9eb")
        light.light_energy = 2.2
        light.omni_range = 13.0
        light.shadow_enabled = false
        add_child(light)

func _add_team_light(position: Vector3, color: Color) -> void:
    var light := OmniLight3D.new()
    light.position = position
    light.light_color = color
    light.light_energy = 3.1
    light.omni_range = 16.0
    light.shadow_enabled = false
    add_child(light)

func _build_rain() -> void:
    var rain := GPUParticles3D.new()
    rain.name = "Rain"
    rain.position = Vector3(0, 12, 0)
    rain.amount = 760
    rain.lifetime = 1.25
    rain.randomness = 0.3
    rain.visibility_aabb = AABB(Vector3(-38, -14, -25), Vector3(76, 28, 50))
    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process.emission_box_extents = Vector3(36, 1, 23)
    process.direction = Vector3(0.08, -1, 0.02)
    process.spread = 4.0
    process.initial_velocity_min = 18.0
    process.initial_velocity_max = 25.0
    process.gravity = Vector3(0, -4, 0)
    rain.process_material = process
    var streak := QuadMesh.new()
    streak.size = Vector2(0.018, 0.62)
    streak.orientation = PlaneMesh.FACE_Z
    var rain_material := StandardMaterial3D.new()
    rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    rain_material.albedo_color = Color(0.58, 0.82, 0.9, 0.34)
    rain_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    streak.material = rain_material
    rain.draw_pass_1 = streak
    add_child(rain)

func _build_ambience() -> void:
    if not ResourceLoader.exists("res://audio/dockyard_rain.wav"): return
    ambience = AudioStreamPlayer.new()
    var stream = load("res://audio/dockyard_rain.wav")
    if stream is AudioStreamWAV:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin = 0
        stream.loop_end = stream.get_length() * stream.mix_rate
    ambience.stream = stream
    ambience.volume_db = -16.0
    add_child(ambience)
    ambience.play()

func _build_navigation_graph() -> void:
    astar.clear()
    var step := 2.75
    var points: Dictionary = {}
    var id := 0
    var z := -19.2
    while z <= 19.2:
        var x := -32.5
        while x <= 32.5:
            var point := Vector3(x, 0.12, z)
            if not _point_blocked(point, 0.62):
                astar.add_point(id, point)
                points[Vector2i(roundi(x / step), roundi(z / step))] = id
                id += 1
            x += step
        z += step
    var ids := astar.get_point_ids()
    for a_index in ids.size():
        var a: int = ids[a_index]
        var pa := astar.get_point_position(a)
        for b_index in range(a_index + 1, ids.size()):
            var b: int = ids[b_index]
            var pb := astar.get_point_position(b)
            if pa.distance_to(pb) <= step * 1.48 and _segment_clear(pa, pb, 0.58):
                astar.connect_points(a, b, true)

func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
    if astar.get_point_count() == 0: return PackedVector3Array([to])
    var start := astar.get_closest_point(from)
    var finish := astar.get_closest_point(to)
    var route := astar.get_point_path(start, finish)
    if route.is_empty(): return PackedVector3Array([to])
    if route[route.size() - 1].distance_to(to) > 0.8: route.append(to)
    return route

func get_random_waypoint() -> Vector3:
    var ids := astar.get_point_ids()
    if ids.is_empty(): return Vector3.ZERO
    return astar.get_point_position(ids[randi() % ids.size()])

func get_cover_points() -> Array[Vector3]:
    var result: Array[Vector3] = []
    for data in obstacles:
        var center: Vector3 = data["position"]
        var size: Vector3 = data["size"]
        result.append(Vector3(center.x + size.x * 0.5 + 0.72, 0.1, center.z))
        result.append(Vector3(center.x - size.x * 0.5 - 0.72, 0.1, center.z))
        result.append(Vector3(center.x, 0.1, center.z + size.z * 0.5 + 0.72))
        result.append(Vector3(center.x, 0.1, center.z - size.z * 0.5 - 0.72))
    return result

func get_team_spawn(team: int, index: int) -> Vector3:
    var list := SPAWNS_ALPHA if team == 0 else SPAWNS_BRAVO
    return list[index % list.size()]

func get_control_position() -> Vector3:
    return Vector3.ZERO

func set_control_team(_team: int) -> void:
    pass

func get_location_name(position: Vector3) -> String:
    if position.x < -24: return "ALPHA YARD"
    if position.x > 24: return "BRAVO YARD"
    if absf(position.z) < 5 and absf(position.x) < 8: return "CUSTOMS"
    if position.z < -7: return "NORTH CONTAINERS"
    if position.z > 7: return "SOUTH CONTAINERS"
    return "MID SERVICE LANE"

func _point_blocked(point: Vector3, margin: float) -> bool:
    for data in obstacles:
        var center: Vector3 = data["position"]
        var size: Vector3 = data["size"]
        if absf(point.x - center.x) < size.x * 0.5 + margin and absf(point.z - center.z) < size.z * 0.5 + margin:
            return true
    return false

func _segment_clear(a: Vector3, b: Vector3, margin: float) -> bool:
    for index in range(1, 7):
        if _point_blocked(a.lerp(b, float(index) / 7.0), margin): return false
    return true

func _static_box(position: Vector3, size: Vector3, node_name: String) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = position
    body.collision_layer = 1
    body.collision_mask = 2
    var shape := BoxShape3D.new()
    shape.size = size
    var collision := CollisionShape3D.new()
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    return body

func _visual_box(position: Vector3, size: Vector3, color: Color, emission: float) -> void:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    instance.material_override = _material(color, emission)
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)

func _material(color: Color, emission: float) -> StandardMaterial3D:
    var key := "%s|%.2f" % [color.to_html(), emission]
    if material_cache.has(key): return material_cache[key]
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.metallic = 0.42
    result.roughness = 0.36
    if emission > 0:
        result.emission_enabled = true
        result.emission = color
        result.emission_energy_multiplier = emission
    material_cache[key] = result
    return result

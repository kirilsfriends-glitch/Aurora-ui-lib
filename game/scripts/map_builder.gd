extends Node3D

const MAP_LIBRARY := preload("res://scripts/map_library.gd")

var map_data: Dictionary
var obstacles: Array = []
var astar := AStar3D.new()
var point_positions: Dictionary = {}
var unit_box: BoxMesh
var material_cache: Dictionary = {}
var control_visual: MeshInstance3D

func _ready() -> void:
    unit_box = BoxMesh.new()
    unit_box.size = Vector3.ONE

func build_map(map_id: String) -> Dictionary:
    return build(MAP_LIBRARY.get_map(map_id))

func build(data: Dictionary) -> Dictionary:
    if unit_box == null:
        unit_box = BoxMesh.new()
        unit_box.size = Vector3.ONE
    map_data = data.duplicate(true)
    obstacles = map_data["obstacles"].duplicate(true)
    _build_environment()
    _build_floor_and_bounds()
    for obstacle in obstacles:
        _add_obstacle(obstacle)
    _build_control_zone()
    _build_navigation_graph()
    return map_data

func _build_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = map_data["sky_top"]
    sky_material.sky_horizon_color = map_data["sky_horizon"]
    sky_material.ground_bottom_color = Color(map_data["floor"]).darkened(0.25)
    sky_material.ground_horizon_color = map_data["sky_horizon"]
    sky_material.sun_angle_max = 9.0
    sky_material.sun_energy_multiplier = 2.2
    var sky := Sky.new()
    sky.sky_material = sky_material
    env.sky = sky
    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_color = Color("d5e8ff")
    env.ambient_light_energy = 1.35
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.adjustment_enabled = true
    env.adjustment_brightness = 1.08
    env.adjustment_contrast = 1.05
    env.adjustment_saturation = 1.08
    world.environment = env
    add_child(world)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-58, -38, 0)
    sun.light_color = Color("fff0d6")
    sun.light_energy = 1.65
    sun.shadow_enabled = false
    add_child(sun)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(38, 145, 0)
    fill.light_color = Color(map_data["accent"]).lerp(Color.WHITE, 0.65)
    fill.light_energy = 0.75
    fill.shadow_enabled = false
    add_child(fill)

func _build_floor_and_bounds() -> void:
    var size: Vector2 = map_data["size"]
    _add_static_box(Vector3(0, -0.45, 0), Vector3(size.x, 0.9, size.y), map_data["floor"], "Floor")
    var wall_color: Color = map_data["wall"]
    _add_static_box(Vector3(0, 1.5, -size.y * 0.5), Vector3(size.x, 3.0, 0.8), wall_color, "NorthBoundary")
    _add_static_box(Vector3(0, 1.5, size.y * 0.5), Vector3(size.x, 3.0, 0.8), wall_color, "SouthBoundary")
    _add_static_box(Vector3(-size.x * 0.5, 1.5, 0), Vector3(0.8, 3.0, size.y), wall_color, "WestBoundary")
    _add_static_box(Vector3(size.x * 0.5, 1.5, 0), Vector3(0.8, 3.0, size.y), wall_color, "EastBoundary")

    var accent: Color = map_data["accent"]
    for edge in [-1.0, 1.0]:
        _add_visual_box(Vector3(0, 0.04, edge * (size.y * 0.5 - 0.7)), Vector3(size.x - 2, 0.04, 0.12), accent, 2.4)

func _add_obstacle(data: Dictionary) -> void:
    var position: Vector3 = data["position"]
    var size: Vector3 = data["size"]
    var kind: String = data["kind"]
    var color: Color = map_data["wall"]
    if kind == "container": color = Color(map_data["accent"]).darkened(0.35)
    elif kind == "crate": color = Color("6e5136")
    elif kind == "lab": color = Color(map_data["wall"]).lightened(0.12)

    var body := StaticBody3D.new()
    body.position = position
    body.name = "Cover_%s" % kind
    add_child(body)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)

    var model_name := ""
    if kind == "container": model_name = "cargo_container"
    elif kind == "crate": model_name = "cover_crate"
    var model_path := "res://models/%s.glb" % model_name
    if not model_name.is_empty() and ResourceLoader.exists(model_path):
        var packed := load(model_path) as PackedScene
        var model: Node3D = packed.instantiate()
        model.scale = size / (Vector3(6.0, 2.6, 2.6) if kind == "container" else Vector3(2.0, 2.0, 2.0))
        body.add_child(model)
    else:
        _add_visual_box(Vector3.ZERO, size, color, 0.28, body)
    _add_visual_box(Vector3(0, size.y * 0.5 + 0.025, 0), Vector3(size.x * 0.9, 0.05, size.z * 0.9), map_data["accent"], 1.6, body)

func _build_control_zone() -> void:
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 3.0
    cylinder.bottom_radius = 3.0
    cylinder.height = 0.06
    cylinder.radial_segments = 32
    control_visual = MeshInstance3D.new()
    control_visual.position = map_data["control"]
    control_visual.mesh = cylinder
    control_visual.material_override = _material(Color(map_data["accent"], 0.34), 2.2, true)
    add_child(control_visual)

func set_control_team(team: int) -> void:
    if not is_instance_valid(control_visual): return
    var color: Color = Color("54eaff") if team == 0 else Color("ff557e") if team == 1 else map_data["accent"]
    control_visual.material_override = _material(Color(color, 0.38), 2.5, true)

func _build_navigation_graph() -> void:
    astar.clear()
    point_positions.clear()
    var size: Vector2 = map_data["size"]
    var id := 0
    var step := 4.0
    var z := -size.y * 0.5 + 2.5
    while z <= size.y * 0.5 - 2.5:
        var x := -size.x * 0.5 + 2.5
        while x <= size.x * 0.5 - 2.5:
            var point := Vector3(x, 0.55, z)
            if not _point_blocked(point, 1.15):
                astar.add_point(id, point)
                point_positions[id] = point
                id += 1
            x += step
        z += step
    var ids := astar.get_point_ids()
    for a_index in ids.size():
        var a: int = ids[a_index]
        for b_index in range(a_index + 1, ids.size()):
            var b: int = ids[b_index]
            var pa := astar.get_point_position(a)
            var pb := astar.get_point_position(b)
            if pa.distance_to(pb) <= step * 1.48 and _segment_clear(pa, pb, 1.0):
                astar.connect_points(a, b, true)

func get_next_path_point(from: Vector3, to: Vector3) -> Vector3:
    var route := find_path(from, to)
    if route.size() >= 2: return route[1]
    if route.size() == 1: return route[0]
    return to

func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
    if astar.get_point_count() == 0: return PackedVector3Array([to])
    var start := astar.get_closest_point(from)
    var finish := astar.get_closest_point(to)
    var route := astar.get_point_path(start, finish)
    if route.is_empty(): return PackedVector3Array([to])
    if route[route.size() - 1].distance_to(to) > 1.0: route.append(to)
    return route

func get_cover_points() -> Array[Vector3]:
    var result: Array[Vector3] = []
    for obstacle in obstacles:
        var center: Vector3 = obstacle["position"]
        var size: Vector3 = obstacle["size"]
        result.append(center + Vector3(size.x * 0.5 + 0.9, 0, 0))
        result.append(center - Vector3(size.x * 0.5 + 0.9, 0, 0))
        result.append(center + Vector3(0, 0, size.z * 0.5 + 0.9))
        result.append(center - Vector3(0, 0, size.z * 0.5 + 0.9))
    return result

func get_control_position() -> Vector3:
    return map_data.get("control", Vector3.ZERO)

func get_team_spawn(team: int, index: int) -> Vector3:
    return get_spawn(team, index)

func get_random_waypoint() -> Vector3:
    var ids := astar.get_point_ids()
    if ids.is_empty(): return Vector3.ZERO
    return astar.get_point_position(ids[randi() % ids.size()])

func get_spawn(team: int, index: int) -> Vector3:
    var list: Array = map_data["spawns_a"] if team == 0 else map_data["spawns_b"]
    return list[index % list.size()]

func _point_blocked(point: Vector3, margin: float) -> bool:
    for obstacle in obstacles:
        var p: Vector3 = obstacle["position"]
        var s: Vector3 = obstacle["size"]
        if absf(point.x - p.x) < s.x * 0.5 + margin and absf(point.z - p.z) < s.z * 0.5 + margin:
            return true
    return false

func _segment_clear(a: Vector3, b: Vector3, margin: float) -> bool:
    for index in range(1, 8):
        var point := a.lerp(b, float(index) / 8.0)
        if _point_blocked(point, margin): return false
    return true

func _add_static_box(position: Vector3, size: Vector3, color: Color, node_name: String) -> void:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = position
    add_child(body)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    _add_visual_box(Vector3.ZERO, size, color, 0.32, body)

func _add_visual_box(position: Vector3, size: Vector3, color: Color, emission: float, parent: Node3D = self) -> void:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.position = position
    mesh_instance.mesh = unit_box
    mesh_instance.scale = size
    mesh_instance.material_override = _material(color, emission)
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh_instance)

func _material(color: Color, emission: float, transparent: bool = false) -> StandardMaterial3D:
    var key := "%s|%.2f|%s" % [color.to_html(true), emission, str(transparent)]
    if material_cache.has(key): return material_cache[key]
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.24
    material.roughness = 0.44
    material.emission_enabled = true
    material.emission = Color(color.r, color.g, color.b, 1)
    material.emission_energy_multiplier = emission
    if transparent or color.a < 1:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material_cache[key] = material
    return material

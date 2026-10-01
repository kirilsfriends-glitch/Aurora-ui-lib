extends SceneTree

const WEAPON_DB := preload("res://scripts/weapon_database.gd")
const MAP_LIBRARY := preload("res://scripts/map_library.gd")
const MAP_BUILDER := preload("res://scripts/map_builder.gd")

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    if not value:
        failures.append(message)
        push_error(message)

func _run() -> void:
    check(WEAPON_DB.ORDER.size() == 12, "Expected exactly 12 launch weapons")
    for weapon_id in WEAPON_DB.ORDER:
        var weapon := WEAPON_DB.get_weapon(weapon_id)
        check(not weapon.is_empty(), "Missing weapon: " + weapon_id)
        check(float(weapon.get("damage", 0)) > 0, "Weapon has no damage: " + weapon_id)
        check(float(weapon.get("range", 0)) > 0, "Weapon has no range: " + weapon_id)
        check(str(weapon.get("model", "")) != "", "Weapon has no model id: " + weapon_id)

    check(MAP_LIBRARY.MAP_ORDER.size() == 5, "Expected five tactical maps")
    for map_id in MAP_LIBRARY.MAP_ORDER:
        var data := MAP_LIBRARY.get_map(map_id)
        check(str(data.get("id", "")) == map_id, "Map id mismatch: " + map_id)
        check((data.get("obstacles", []) as Array).size() >= 10, "Map needs tactical cover: " + map_id)
        check((data.get("spawns_a", []) as Array).size() >= 5, "Alpha spawns missing: " + map_id)
        check((data.get("spawns_b", []) as Array).size() >= 5, "Bravo spawns missing: " + map_id)
        var builder := MAP_BUILDER.new()
        root.add_child(builder)
        builder.build(data)
        check(builder.get_team_spawn(0, 0) != builder.get_team_spawn(1, 0), "Team spawns overlap: " + map_id)
        check(not builder.get_cover_points().is_empty(), "Cover graph missing: " + map_id)
        check(not builder.find_path(builder.get_team_spawn(0, 0), builder.get_team_spawn(1, 0)).is_empty(), "Path graph missing: " + map_id)
        builder.free()

    var required_scripts := [
        "res://scripts/game.gd", "res://scripts/player_controller.gd", "res://scripts/bot_controller.gd",
        "res://scripts/weapon_controller.gd", "res://scripts/touch_fps_controls.gd", "res://scripts/lobby.gd", "res://scripts/hud.gd"
    ]
    for path in required_scripts:
        check(ResourceLoader.exists(path), "Missing gameplay system: " + path)

    if failures.is_empty():
        print("AURORA STRIKE SMOKE TEST PASSED: 5 maps, 12 weapons, AI, lobby, HUD and controls loaded")
        quit(0)
    else:
        print("AURORA STRIKE SMOKE TEST FAILED: %d issue(s)" % failures.size())
        quit(1)

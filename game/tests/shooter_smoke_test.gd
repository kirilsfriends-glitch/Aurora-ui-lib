extends SceneTree

const WEAPON_DB := preload("res://scripts/weapon_database.gd")
const DOCKYARD_MAP := preload("res://scripts/dockyard_map.gd")

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    if not value:
        failures.append(message)
        push_error(message)

func _run() -> void:
    check(WEAPON_DB.ACTIVE_ORDER.size() == 4, "Vertical slice must expose four tuned weapons")
    for weapon_id in WEAPON_DB.ACTIVE_ORDER:
        var weapon := WEAPON_DB.get_weapon(weapon_id)
        check(not weapon.is_empty(), "Missing active weapon: " + weapon_id)
        check(float(weapon.get("damage", 0)) > 0, "Weapon has no damage: " + weapon_id)
        check(float(weapon.get("range", 0)) > 0, "Weapon has no range: " + weapon_id)
        check(ResourceLoader.exists("res://models/%s.glb" % weapon["model"]), "Weapon GLB missing: " + weapon_id)
        check(ResourceLoader.exists("res://audio/%s_fire.wav" % weapon_id), "Weapon audio missing: " + weapon_id)

    var map := DOCKYARD_MAP.new()
    root.add_child(map)
    map.build()
    check(map.get_team_spawn(0, 0) != map.get_team_spawn(1, 0), "Team spawns overlap")
    check(map.get_cover_points().size() >= 60, "Authored map needs a dense cover graph")
    var route := map.find_path(map.get_team_spawn(0, 0), map.get_team_spawn(1, 0))
    check(not route.is_empty(), "AStar could not route between team spawns")
    check(map.get_location_name(Vector3.ZERO) == "CUSTOMS", "Map location zones are unavailable")
    map.free()

    var required_assets := [
        "res://ui/dockyard_briefing.webp", "res://models/dockyard_environment.glb",
        "res://models/tactical_operator.glb", "res://audio/dockyard_rain.wav",
        "res://audio/hit_confirm.wav", "res://audio/rifle_reload.wav",
    ]
    for path in required_assets:
        check(ResourceLoader.exists(path), "Missing vertical slice asset: " + path)

    # Deploy the real entry scene. This runs authored map construction, lobby/HUD,
    # generated models, procedural audio, signal wiring, controllers, and all 10 AI actors.
    var main_scene := load("res://main.tscn") as PackedScene
    check(main_scene != null, "Main scene could not be loaded")
    if main_scene != null:
        var game = main_scene.instantiate()
        root.add_child(game)
        await process_frame
        check(game.lobby != null and game.hud != null, "Lobby or HUD failed to initialize")
        await game.start_match("ak47", 0.70)
        check(game.actors.size() == 10, "Expected a complete 5v5 deployment")
        check(game.local_player != null and game.local_player.alive, "FPS player failed to spawn")
        check(game.get_living_allies(0).size() == 5, "Alpha squad did not spawn five operators")
        check(game.get_living_allies(1).size() == 5, "Bravo squad did not spawn five operators")
        check(game.map_runtime.get_cover_points().size() >= 60, "Runtime cover data was lost")
        game.free()

    if failures.is_empty():
        print("AURORA STRIKE VERTICAL SLICE PASSED: authored map, audio, UI, four weapons, and 5v5 deployment")
        quit(0)
    else:
        print("AURORA STRIKE VERTICAL SLICE FAILED: %d issue(s)" % failures.size())
        quit(1)

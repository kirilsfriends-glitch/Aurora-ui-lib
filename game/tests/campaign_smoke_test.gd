extends SceneTree


func _initialize() -> void:
    call_deferred("_run_campaign_smoke_test")


func _run_campaign_smoke_test() -> void:
    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        push_error("Unable to load main scene")
        quit(1)
        return

    var game := packed.instantiate()
    root.add_child(game)
    await process_frame

    var player_capsule: CapsuleShape3D
    for child in game.player.get_children():
        if child is CollisionShape3D and child.shape is CapsuleShape3D:
            player_capsule = child.shape
            break
    if player_capsule == null or player_capsule.radius > 0.31:
        push_error("Player collision core is missing or too large")
        quit(1)
        return

    for level_index in range(10):
        game._load_level(level_index)
        await process_frame
        if game.current_level != level_index or game.level_root == null or game.portal == null:
            push_error("Level %d failed to initialize" % (level_index + 1))
            quit(1)
            return
        if level_index in [2, 3] and (
            not game.rotating_lasers.is_empty() or not game.moving_hazards.is_empty()
        ):
            push_error("Level %d still contains a red lethal hazard" % (level_index + 1))
            quit(1)
            return
        for sentinel in game.moving_hazards:
            for child in sentinel.get_children():
                if child is CollisionShape3D and child.shape is SphereShape3D:
                    if child.shape.radius > 0.31:
                        push_error("Level %d sentinel collision is too large" % (level_index + 1))
                        quit(1)
                        return
        print("CAMPAIGN_SMOKE_LEVEL_OK:", level_index + 1)

    game.queue_free()
    await process_frame
    print("CAMPAIGN_SMOKE_OK:10")
    quit(0)

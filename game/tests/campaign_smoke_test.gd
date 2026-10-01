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

    for level_index in range(10):
        game._load_level(level_index)
        await process_frame
        if game.current_level != level_index or game.level_root == null or game.portal == null:
            push_error("Level %d failed to initialize" % (level_index + 1))
            quit(1)
            return
        print("CAMPAIGN_SMOKE_LEVEL_OK:", level_index + 1)

    game.queue_free()
    await process_frame
    print("CAMPAIGN_SMOKE_OK:10")
    quit(0)

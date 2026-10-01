extends RefCounted

const MAP_IDS := ["dockyard", "sandstone", "metro", "frostline", "neon_lab"]
const MAP_ORDER := MAP_IDS

static func get_map(map_id: String) -> Dictionary:
    match map_id:
        "sandstone": return _sandstone()
        "metro": return _metro()
        "frostline": return _frostline()
        "neon_lab": return _neon_lab()
        _: return _dockyard()

static func _box(x: float, z: float, sx: float, sy: float, sz: float, kind: String = "wall") -> Dictionary:
    return {"position": Vector3(x, sy * 0.5, z), "size": Vector3(sx, sy, sz), "kind": kind}

static func _dockyard() -> Dictionary:
    return {
        "id": "dockyard", "name": "DOCKYARD ZERO", "subtitle": "Container lanes and close flanks",
        "size": Vector2(48, 38), "floor": Color("24384b"), "wall": Color("355b70"),
        "accent": Color("51f0da"), "sky_top": Color("294a68"), "sky_horizon": Color("e18c63"),
        "spawns_a": [Vector3(-20, 1, 14), Vector3(-18, 1, 8), Vector3(-20, 1, 2), Vector3(-18, 1, -7), Vector3(-20, 1, -14)],
        "spawns_b": [Vector3(20, 1, -14), Vector3(18, 1, -8), Vector3(20, 1, -2), Vector3(18, 1, 7), Vector3(20, 1, 14)],
        "control": Vector3(0, 0.15, 0),
        "obstacles": [
            _box(-12, 10, 6, 2.8, 2.8, "container"), _box(-5, 10, 6, 2.8, 2.8, "container"),
            _box(9, 11, 8, 2.8, 2.8, "container"), _box(14, 5, 2.8, 2.8, 7, "container"),
            _box(-13, -9, 8, 2.8, 2.8, "container"), _box(-5, -9, 4, 2.8, 2.8, "container"),
            _box(8, -10, 7, 2.8, 2.8, "container"), _box(14, -4, 2.8, 2.8, 7, "container"),
            _box(0, 3, 4, 2.2, 4, "crate"), _box(0, -4, 4, 2.2, 4, "crate"),
            _box(-8, 0, 2.2, 2.2, 2.2, "crate"), _box(8, 0, 2.2, 2.2, 2.2, "crate"),
        ]
    }

static func _sandstone() -> Dictionary:
    return {
        "id": "sandstone", "name": "SANDSTONE CITADEL", "subtitle": "Courtyards, arches, and long sightlines",
        "size": Vector2(52, 42), "floor": Color("82684c"), "wall": Color("ae8a5f"),
        "accent": Color("ffd16a"), "sky_top": Color("4b79a2"), "sky_horizon": Color("ffc488"),
        "spawns_a": [Vector3(-22, 1, 16), Vector3(-20, 1, 9), Vector3(-22, 1, 1), Vector3(-20, 1, -8), Vector3(-22, 1, -16)],
        "spawns_b": [Vector3(22, 1, -16), Vector3(20, 1, -9), Vector3(22, 1, -1), Vector3(20, 1, 8), Vector3(22, 1, 16)],
        "control": Vector3(0, 0.15, 0),
        "obstacles": [
            _box(-12, 13, 12, 3.6, 1.2), _box(-7, 8, 1.2, 3.6, 9),
            _box(12, -13, 12, 3.6, 1.2), _box(7, -8, 1.2, 3.6, 9),
            _box(10, 13, 1.2, 4.2, 11), _box(-10, -13, 1.2, 4.2, 11),
            _box(0, 8, 8, 3.2, 1.2), _box(0, -8, 8, 3.2, 1.2),
            _box(-14, 0, 5, 2.6, 5, "crate"), _box(14, 0, 5, 2.6, 5, "crate"),
            _box(0, 0, 4, 2.8, 4, "crate"), _box(-3, 16, 2.2, 2.2, 2.2, "crate"),
            _box(3, -16, 2.2, 2.2, 2.2, "crate"),
        ]
    }

static func _metro() -> Dictionary:
    return {
        "id": "metro", "name": "METRO NEXUS", "subtitle": "Three fast lanes beneath the city",
        "size": Vector2(56, 34), "floor": Color("26303a"), "wall": Color("4e5d68"),
        "accent": Color("ffcf56"), "sky_top": Color("182b46"), "sky_horizon": Color("6c8da5"),
        "spawns_a": [Vector3(-24, 1, 12), Vector3(-23, 1, 6), Vector3(-24, 1, 0), Vector3(-23, 1, -6), Vector3(-24, 1, -12)],
        "spawns_b": [Vector3(24, 1, -12), Vector3(23, 1, -6), Vector3(24, 1, 0), Vector3(23, 1, 6), Vector3(24, 1, 12)],
        "control": Vector3(0, 0.15, 0),
        "obstacles": [
            _box(-10, 7, 14, 2.2, 1.0), _box(8, 7, 12, 2.2, 1.0),
            _box(-8, -7, 12, 2.2, 1.0), _box(11, -7, 14, 2.2, 1.0),
            _box(-14, 0, 1.2, 3.4, 8), _box(14, 0, 1.2, 3.4, 8),
            _box(0, 0, 6, 2.5, 3, "container"),
            _box(-4, 13, 3, 2.0, 3, "crate"), _box(5, -13, 3, 2.0, 3, "crate"),
            _box(-21, 0, 2.2, 2.2, 2.2, "crate"), _box(21, 0, 2.2, 2.2, 2.2, "crate"),
        ]
    }

static func _frostline() -> Dictionary:
    return {
        "id": "frostline", "name": "FROSTLINE BASE", "subtitle": "Research blocks in a polar storm",
        "size": Vector2(46, 46), "floor": Color("7893a5"), "wall": Color("b4ced8"),
        "accent": Color("72f4ff"), "sky_top": Color("486d8a"), "sky_horizon": Color("d7f3ff"),
        "spawns_a": [Vector3(-19, 1, 18), Vector3(-18, 1, 10), Vector3(-20, 1, 2), Vector3(-18, 1, -8), Vector3(-19, 1, -18)],
        "spawns_b": [Vector3(19, 1, -18), Vector3(18, 1, -10), Vector3(20, 1, -2), Vector3(18, 1, 8), Vector3(19, 1, 18)],
        "control": Vector3(0, 0.15, 0),
        "obstacles": [
            _box(-10, 10, 9, 3.5, 7, "lab"), _box(10, -10, 9, 3.5, 7, "lab"),
            _box(10, 11, 6, 3.0, 6, "lab"), _box(-10, -11, 6, 3.0, 6, "lab"),
            _box(0, 0, 5, 3.0, 5, "lab"),
            _box(-18, 1, 2.4, 2.4, 6, "container"), _box(18, -1, 2.4, 2.4, 6, "container"),
            _box(0, 17, 8, 2.4, 2.4, "container"), _box(0, -17, 8, 2.4, 2.4, "container"),
            _box(-2, 10, 2, 2, 2, "crate"), _box(2, -10, 2, 2, 2, "crate"),
        ]
    }

static func _neon_lab() -> Dictionary:
    return {
        "id": "neon_lab", "name": "NEON LABS", "subtitle": "Symmetric competitive arena",
        "size": Vector2(50, 40), "floor": Color("242451"), "wall": Color("403b78"),
        "accent": Color("ff59d6"), "sky_top": Color("24214f"), "sky_horizon": Color("7458b5"),
        "spawns_a": [Vector3(-21, 1, 15), Vector3(-20, 1, 8), Vector3(-22, 1, 0), Vector3(-20, 1, -8), Vector3(-21, 1, -15)],
        "spawns_b": [Vector3(21, 1, -15), Vector3(20, 1, -8), Vector3(22, 1, 0), Vector3(20, 1, 8), Vector3(21, 1, 15)],
        "control": Vector3(0, 0.15, 0),
        "obstacles": [
            _box(-12, 10, 8, 3.2, 3, "lab"), _box(12, -10, 8, 3.2, 3, "lab"),
            _box(12, 10, 3, 3.2, 8, "lab"), _box(-12, -10, 3, 3.2, 8, "lab"),
            _box(0, 0, 7, 3.8, 7, "lab"),
            _box(-9, 0, 2, 2, 5, "crate"), _box(9, 0, 2, 2, 5, "crate"),
            _box(0, 12, 5, 2, 2, "crate"), _box(0, -12, 5, 2, 2, "crate"),
            _box(-19, 7, 2, 2.4, 4, "container"), _box(19, -7, 2, 2.4, 4, "container"),
        ]
    }

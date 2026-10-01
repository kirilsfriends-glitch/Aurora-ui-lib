extends RefCounted

# The vertical slice deliberately exposes four tuned weapons. The remaining
# definitions stay in the database for the later content expansion, but are not
# presented as finished launch content.
const ACTIVE_ORDER := ["ak47", "m4a1", "awp", "glock"]
const ORDER := [
    "ak47", "m4a1", "awp", "scout", "mp5", "p90",
    "nova", "deagle", "glock", "usp", "knife", "frag",
]

const WEAPONS := {
    "ak47": {"name": "AK-47", "class": "RIFLE", "damage": 36.0, "rpm": 600.0, "mag": 30, "reserve": 90, "reload": 2.35, "spread": 0.012, "recoil": 1.55, "range": 90.0, "pellets": 1, "auto": true, "scope": 0, "move": 0.94, "model": "ak47"},
    "m4a1": {"name": "M4A1", "class": "RIFLE", "damage": 31.0, "rpm": 720.0, "mag": 30, "reserve": 90, "reload": 2.15, "spread": 0.009, "recoil": 1.15, "range": 90.0, "pellets": 1, "auto": true, "scope": 0, "move": 0.96, "model": "m4a1"},
    "awp": {"name": "AWP", "class": "SNIPER", "damage": 118.0, "rpm": 48.0, "mag": 10, "reserve": 30, "reload": 3.1, "spread": 0.001, "recoil": 4.8, "range": 180.0, "pellets": 1, "auto": false, "scope": 2, "move": 0.72, "model": "awp"},
    "scout": {"name": "SCOUT", "class": "SNIPER", "damage": 78.0, "rpm": 72.0, "mag": 10, "reserve": 40, "reload": 2.45, "spread": 0.0025, "recoil": 2.7, "range": 150.0, "pellets": 1, "auto": false, "scope": 2, "move": 0.86, "model": "scout"},
    "mp5": {"name": "MP5", "class": "SMG", "damage": 25.0, "rpm": 800.0, "mag": 30, "reserve": 120, "reload": 1.9, "spread": 0.018, "recoil": 0.72, "range": 58.0, "pellets": 1, "auto": true, "scope": 0, "move": 1.05, "model": "mp5"},
    "p90": {"name": "P90", "class": "SMG", "damage": 23.0, "rpm": 900.0, "mag": 50, "reserve": 150, "reload": 2.6, "spread": 0.021, "recoil": 0.65, "range": 55.0, "pellets": 1, "auto": true, "scope": 0, "move": 1.04, "model": "p90"},
    "nova": {"name": "NOVA", "class": "SHOTGUN", "damage": 13.0, "rpm": 70.0, "mag": 8, "reserve": 32, "reload": 2.8, "spread": 0.065, "recoil": 3.5, "range": 28.0, "pellets": 8, "auto": false, "scope": 0, "move": 0.9, "model": "nova_shotgun"},
    "deagle": {"name": "DESERT EAGLE", "class": "PISTOL", "damage": 56.0, "rpm": 240.0, "mag": 7, "reserve": 35, "reload": 1.75, "spread": 0.014, "recoil": 2.6, "range": 75.0, "pellets": 1, "auto": false, "scope": 0, "move": 1.0, "model": "deagle"},
    "glock": {"name": "GLOCK-18", "class": "PISTOL", "damage": 24.0, "rpm": 420.0, "mag": 20, "reserve": 80, "reload": 1.65, "spread": 0.018, "recoil": 0.8, "range": 50.0, "pellets": 1, "auto": false, "scope": 0, "move": 1.02, "model": "glock"},
    "usp": {"name": "USP-S", "class": "PISTOL", "damage": 32.0, "rpm": 360.0, "mag": 12, "reserve": 60, "reload": 1.7, "spread": 0.011, "recoil": 1.0, "range": 62.0, "pellets": 1, "auto": false, "scope": 0, "move": 1.02, "model": "usp"},
    "knife": {"name": "TACTICAL KNIFE", "class": "MELEE", "damage": 68.0, "rpm": 90.0, "mag": -1, "reserve": -1, "reload": 0.0, "spread": 0.0, "recoil": 0.25, "range": 2.3, "pellets": 1, "auto": false, "scope": 0, "move": 1.12, "model": "knife"},
    "frag": {"name": "FRAG GRENADE", "class": "GRENADE", "damage": 105.0, "rpm": 35.0, "mag": 1, "reserve": 2, "reload": 1.2, "spread": 0.0, "recoil": 0.5, "range": 34.0, "pellets": 1, "auto": false, "scope": 0, "move": 1.0, "model": "grenade"},
}

static func get_weapon(weapon_id: String) -> Dictionary:
    return WEAPONS.get(weapon_id, WEAPONS["ak47"]).duplicate(true)

static func get_bot_loadout(index: int, team: int) -> String:
    var pools := [
        ["ak47", "m4a1", "mp5", "p90", "nova", "awp"],
        ["m4a1", "ak47", "mp5", "scout", "p90", "awp"],
    ]
    return pools[team % 2][index % pools[team % 2].size()]

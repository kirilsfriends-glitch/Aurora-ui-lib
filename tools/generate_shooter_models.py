#!/usr/bin/env python3
"""Generate original Aurora Strike weapons, operator, and tactical props in Blender.

Run with Blender 4.3+: blender --background --python tools/generate_shooter_models.py
Every mesh is built procedurally from primitives; no third-party geometry or textures.
"""
from __future__ import annotations

import math
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "game" / "models"
BLEND_PATH = ROOT / "assets" / "blender" / "aurora_strike_assets.blend"
MODEL_DIR.mkdir(parents=True, exist_ok=True)
BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for block in bpy.data.materials:
    bpy.data.materials.remove(block)


def material(name, color, metallic=0.0, roughness=0.45, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 2.5
    return mat


MAT = {
    "gunmetal": material("Gunmetal", (0.055, 0.065, 0.075), 0.82, 0.25),
    "steel": material("Machined Steel", (0.19, 0.21, 0.23), 0.88, 0.18),
    "black": material("Polymer Black", (0.018, 0.022, 0.025), 0.12, 0.42),
    "tan": material("Tactical Tan", (0.34, 0.27, 0.17), 0.18, 0.52),
    "olive": material("Operator Olive", (0.17, 0.22, 0.12), 0.05, 0.7),
    "wood": material("Walnut Laminate", (0.23, 0.075, 0.028), 0.02, 0.36),
    "blue": material("Aurora Blue", (0.02, 0.34, 0.46), 0.45, 0.24, (0.02, 0.38, 0.56)),
    "red": material("Warning Red", (0.5, 0.035, 0.025), 0.25, 0.34),
    "glass": material("Optic Glass", (0.025, 0.16, 0.2), 0.4, 0.08, (0.02, 0.15, 0.22)),
    "skin": material("Skin", (0.35, 0.21, 0.14), 0.0, 0.68),
    "fabric": material("Fabric", (0.07, 0.09, 0.075), 0.0, 0.92),
    "cargo": material("Cargo Paint", (0.075, 0.25, 0.29), 0.4, 0.55),
    "crate": material("Composite Crate", (0.28, 0.19, 0.095), 0.08, 0.75),
}


def parent_to(obj, root):
    obj.parent = root
    return obj


def cube(name, location, scale, mat, root, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0] / 2, scale[1] / 2, scale[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    if bevel > 0:
        modifier = obj.modifiers.new("Edge bevel", "BEVEL")
        modifier.width = min(bevel, min(scale) * 0.22)
        modifier.segments = 2
    return parent_to(obj, root)


def cylinder(name, location, radius, depth, mat, root, vertices=20, axis="Y"):
    rotation = (math.pi / 2, 0, 0) if axis == "Y" else (0, math.pi / 2, 0) if axis == "X" else (0, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    if mat:
        obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Rim bevel", "BEVEL")
    bevel.width = min(0.025, radius * 0.14)
    bevel.segments = 2
    return parent_to(obj, root)


def sphere(name, location, scale, mat, root):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return parent_to(obj, root)


def root_for(asset_name):
    root = bpy.data.objects.new(asset_name, None)
    bpy.context.collection.objects.link(root)
    return root


def add_scope(root, y=-0.23, long=False):
    length = 0.48 if long else 0.28
    cylinder("Scope body", (0, y, 0.22), 0.072, length, MAT["black"], root)
    cylinder("Scope objective", (0, y - length * 0.48, 0.22), 0.088, 0.055, MAT["gunmetal"], root)
    cylinder("Optic glass", (0, y - length * 0.515, 0.22), 0.07, 0.008, MAT["glass"], root)
    cube("Scope rail", (0, y, 0.13), (0.09, length * 0.82, 0.055), MAT["steel"], root, 0.012)


def add_iron_sights(root, front_y=-0.83, rear_y=-0.05):
    cube("Front sight", (0, front_y, 0.19), (0.035, 0.035, 0.17), MAT["steel"], root, 0.008)
    cube("Rear sight", (0, rear_y, 0.17), (0.12, 0.04, 0.08), MAT["steel"], root, 0.008)


def build_rifle(asset, style="modern", sniper=False, smg=False):
    root = root_for(asset)
    receiver_length = 0.55 if not smg else 0.43
    barrel_length = 0.78 if sniper else 0.49 if not smg else 0.31
    body_mat = MAT["wood"] if style == "ak" else MAT["tan"] if style == "scout" else MAT["gunmetal"]
    cube("Receiver", (0, -0.16, 0.03), (0.2, receiver_length, 0.22), MAT["gunmetal"], root)
    cube("Upper handguard", (0, -0.53, 0.065), (0.17, 0.38 if not sniper else 0.55, 0.15), body_mat, root)
    cylinder("Barrel", (0, -0.78 if not sniper else -0.96, 0.07), 0.027 if not sniper else 0.034, barrel_length, MAT["steel"], root)
    cylinder("Muzzle brake", (0, -1.04 if not sniper else -1.35, 0.07), 0.045, 0.13, MAT["gunmetal"], root)
    grip = cube("Pistol grip", (0, 0.04, -0.16), (0.12, 0.16, 0.34), MAT["black"], root)
    grip.rotation_euler.x = -0.25
    mag_scale = (0.13, 0.23, 0.34) if not smg else (0.11, 0.15, 0.30)
    magazine = cube("Magazine", (0, -0.18, -0.18), mag_scale, MAT["steel"], root)
    magazine.rotation_euler.x = -0.14 if style == "ak" else 0.0
    if style == "p90":
        magazine.location = (0, -0.25, 0.17)
        magazine.dimensions = (0.12, 0.52, 0.07)
    if style == "ak":
        cube("Wood stock", (0, 0.28, 0.01), (0.17, 0.42, 0.20), MAT["wood"], root)
        cylinder("Gas tube", (0, -0.56, 0.16), 0.034, 0.48, MAT["steel"], root)
    elif style == "p90":
        cube("Bullpup stock", (0, 0.22, -0.01), (0.26, 0.46, 0.35), MAT["black"], root)
        cube("Thumb opening", (0, 0.06, -0.03), (0.28, 0.16, 0.12), MAT["blue"], root)
    else:
        cube("Buffer tube", (0, 0.27, 0.07), (0.085, 0.42, 0.085), MAT["steel"], root)
        cube("Adjustable stock", (0, 0.48, 0.04), (0.19, 0.34, 0.26), MAT["black" if style != "scout" else "tan"], root)
    if sniper:
        add_scope(root, -0.25, True)
        cube("Cheek rest", (0, 0.31, 0.16), (0.16, 0.33, 0.10), MAT["black"], root)
        cylinder("Bolt handle", (0.13, -0.04, 0.09), 0.026, 0.18, MAT["steel"], root, axis="X")
    else:
        add_iron_sights(root)
    cube("Aurora serial plate", (0.106, -0.13, 0.06), (0.012, 0.24, 0.055), MAT["blue"], root, 0.005)
    return root


def build_pistol(asset, suppressed=False, heavy=False):
    root = root_for(asset)
    length = 0.47 if heavy else 0.39
    width = 0.17 if heavy else 0.135
    cube("Slide", (0, -0.19, 0.10), (width, length, 0.15), MAT["steel" if heavy else "gunmetal"], root)
    cube("Frame", (0, -0.12, -0.015), (width * 0.95, length * 0.72, 0.12), MAT["black"], root)
    grip = cube("Grip", (0, 0.0, -0.21), (0.14, 0.19, 0.38), MAT["black"], root)
    grip.rotation_euler.x = -0.17
    cylinder("Barrel", (0, -0.43, 0.10), 0.025, 0.22 if suppressed else 0.10, MAT["steel"], root)
    if suppressed:
        cylinder("Suppressor", (0, -0.62, 0.10), 0.055, 0.42, MAT["black"], root)
    cube("Front sight", (0, -0.36, 0.20), (0.025, 0.035, 0.055), MAT["blue"], root, 0.004)
    cube("Trigger guard", (0, -0.15, -0.10), (0.15, 0.17, 0.035), MAT["steel"], root, 0.015)
    cube("Magazine base", (0, 0.045, -0.40), (0.15, 0.16, 0.045), MAT["blue"], root, 0.01)
    return root


def build_shotgun(asset):
    root = root_for(asset)
    cube("Receiver", (0, -0.1, 0.04), (0.21, 0.46, 0.23), MAT["gunmetal"], root)
    cylinder("Barrel", (0, -0.78, 0.09), 0.038, 1.05, MAT["steel"], root)
    cylinder("Tube magazine", (0, -0.68, -0.005), 0.033, 0.78, MAT["gunmetal"], root)
    cube("Pump", (0, -0.56, 0.0), (0.2, 0.34, 0.19), MAT["tan"], root)
    cube("Stock", (0, 0.35, 0.01), (0.2, 0.58, 0.27), MAT["tan"], root)
    cube("Shell port", (0.108, -0.08, 0.06), (0.012, 0.19, 0.09), MAT["blue"], root, 0.002)
    add_iron_sights(root, -1.27, -0.14)
    return root


def build_knife(asset):
    root = root_for(asset)
    cube("Grip", (0, 0.20, 0), (0.13, 0.40, 0.11), MAT["black"], root, 0.025)
    cube("Guard", (0, -0.03, 0), (0.31, 0.06, 0.06), MAT["steel"], root, 0.012)
    blade = cube("Blade", (0, -0.38, 0), (0.10, 0.68, 0.025), MAT["steel"], root, 0.008)
    blade.scale.x = 0.65
    cube("Blade spine", (0.043, -0.32, 0.01), (0.025, 0.48, 0.035), MAT["blue"], root, 0.004)
    return root


def build_grenade(asset):
    root = root_for(asset)
    cylinder("Frag body", (0, 0, 0), 0.16, 0.34, MAT["olive"], root, vertices=12, axis="Z")
    for z in (-0.12, -0.04, 0.04, 0.12):
        cylinder("Fragment ring", (0, 0, z), 0.169, 0.016, MAT["gunmetal"], root, vertices=12, axis="Z")
    cube("Fuse", (0, 0, 0.22), (0.12, 0.12, 0.12), MAT["steel"], root)
    cube("Safety lever", (0.12, 0, 0.22), (0.20, 0.055, 0.06), MAT["tan"], root, 0.015)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.09, minor_radius=0.012, location=(0.16, 0, 0.25), rotation=(math.pi/2, 0, 0))
    pin = bpy.context.object
    pin.name = "Safety pin"
    pin.data.materials.append(MAT["steel"])
    parent_to(pin, root)
    return root


def build_operator(asset):
    root = root_for(asset)
    cube("Boot L", (-0.13, 0.02, 0.10), (0.20, 0.34, 0.19), MAT["black"], root)
    cube("Boot R", (0.13, 0.02, 0.10), (0.20, 0.34, 0.19), MAT["black"], root)
    cylinder("Lower leg L", (-0.13, 0, 0.42), 0.11, 0.52, MAT["fabric"], root, axis="Z")
    cylinder("Lower leg R", (0.13, 0, 0.42), 0.11, 0.52, MAT["fabric"], root, axis="Z")
    cylinder("Upper leg L", (-0.13, 0, 0.82), 0.135, 0.46, MAT["olive"], root, axis="Z")
    cylinder("Upper leg R", (0.13, 0, 0.82), 0.135, 0.46, MAT["olive"], root, axis="Z")
    cube("Pelvis", (0, 0, 1.05), (0.46, 0.28, 0.30), MAT["fabric"], root)
    cube("Armored torso", (0, 0, 1.37), (0.58, 0.32, 0.56), MAT["olive"], root, 0.09)
    cube("Plate carrier", (0, -0.18, 1.39), (0.48, 0.12, 0.42), MAT["black"], root, 0.05)
    for x in (-0.15, 0, 0.15):
        cube("Magazine pouch", (x, -0.255, 1.29), (0.12, 0.08, 0.24), MAT["tan"], root, 0.018)
    cylinder("Arm L", (-0.38, 0, 1.38), 0.11, 0.62, MAT["fabric"], root, axis="Z")
    cylinder("Arm R", (0.38, 0, 1.38), 0.11, 0.62, MAT["fabric"], root, axis="Z")
    sphere("Glove L", (-0.38, 0, 1.06), (0.12, 0.11, 0.13), MAT["black"], root)
    sphere("Glove R", (0.38, 0, 1.06), (0.12, 0.11, 0.13), MAT["black"], root)
    cylinder("Neck", (0, 0, 1.72), 0.10, 0.14, MAT["skin"], root, axis="Z")
    sphere("Head", (0, 0, 1.88), (0.17, 0.16, 0.20), MAT["skin"], root)
    sphere("Helmet", (0, 0.015, 1.98), (0.205, 0.19, 0.15), MAT["black"], root)
    cube("Goggles", (0, -0.155, 1.90), (0.29, 0.055, 0.09), MAT["glass"], root, 0.025)
    cube("Radio", (0.32, 0.03, 1.47), (0.12, 0.14, 0.25), MAT["black"], root, 0.02)
    cube("Team patch", (0, -0.247, 1.57), (0.24, 0.012, 0.075), MAT["blue"], root, 0.004)
    return root


def build_container(asset):
    root = root_for(asset)
    cube("Container hull", (0, 0, 1.3), (6.0, 2.6, 2.6), MAT["cargo"], root, 0.06)
    for x in (-2.85, -1.9, -0.95, 0, 0.95, 1.9, 2.85):
        cube("Rib", (x, -1.315, 1.3), (0.085, 0.07, 2.42), MAT["steel"], root, 0.012)
        cube("Rib", (x, 1.315, 1.3), (0.085, 0.07, 2.42), MAT["steel"], root, 0.012)
    for x in (-2.94, 2.94):
        for z in (0.12, 2.48):
            cube("Corner casting", (x, -1.33, z), (0.18, 0.12, 0.18), MAT["blue"], root, 0.025)
    return root


def build_crate(asset):
    root = root_for(asset)
    cube("Crate core", (0, 0, 1), (2, 2, 2), MAT["crate"], root, 0.06)
    for z in (0.14, 1.86):
        cube("Horizontal brace", (0, -1.02, z), (1.88, 0.09, 0.16), MAT["steel"], root, 0.02)
    for x in (-0.86, 0.86):
        cube("Vertical brace", (x, -1.02, 1), (0.15, 0.09, 1.88), MAT["steel"], root, 0.02)
    cube("Aurora cargo mark", (0, -1.07, 1), (0.64, 0.025, 0.32), MAT["blue"], root, 0.006)
    return root


def export_asset(name, root, showcase_position):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(MODEL_DIR / f"{name}.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )
    root.location = showcase_position


builders = [
    ("ak47", lambda: build_rifle("AK-47", "ak")),
    ("m4a1", lambda: build_rifle("M4A1", "modern")),
    ("awp", lambda: build_rifle("AWP", "modern", sniper=True)),
    ("scout", lambda: build_rifle("Scout", "scout", sniper=True)),
    ("mp5", lambda: build_rifle("MP5", "modern", smg=True)),
    ("p90", lambda: build_rifle("P90", "p90", smg=True)),
    ("nova_shotgun", lambda: build_shotgun("Nova")),
    ("deagle", lambda: build_pistol("Desert Eagle", heavy=True)),
    ("glock", lambda: build_pistol("Glock-18")),
    ("usp", lambda: build_pistol("USP-S", suppressed=True)),
    ("knife", lambda: build_knife("Tactical Knife")),
    ("grenade", lambda: build_grenade("Frag Grenade")),
    ("tactical_operator", lambda: build_operator("Tactical Operator")),
    ("cargo_container", lambda: build_container("Cargo Container")),
    ("cover_crate", lambda: build_crate("Cover Crate")),
]

for index, (name, builder) in enumerate(builders):
    asset_root = builder()
    col = index % 5
    row = index // 5
    export_asset(name, asset_root, (col * 7.5, row * 5.5, 0))

# A clean source file with every generated asset arranged in an inspectable gallery.
bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
bpy.context.scene.world.color = (0.018, 0.028, 0.045)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH), compress=True)
print(f"Generated {len(builders)} original GLB assets and {BLEND_PATH}")

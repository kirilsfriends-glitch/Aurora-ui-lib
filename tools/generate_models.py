#!/usr/bin/env python3
"""Generate Aurora Drift 3D models with Blender 4.3 and export them as GLB.

Run with Blender's Python runtime:
    blender --background --python tools/generate_models.py
Or with the official bpy wheel:
    python tools/generate_models.py
"""

from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "models"
SOURCE_OUT = ROOT / "assets" / "blender"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE_OUT.mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)
    for block in bpy.data.collections:
        if block.name != "Collection":
            bpy.data.collections.remove(block)


def material(name, color, metallic=0.25, roughness=0.3, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = color
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0.0:
        emission_input = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if emission_input:
            emission_input.default_value = color
        strength_input = bsdf.inputs.get("Emission Strength")
        if strength_input:
            strength_input.default_value = emission
    return mat


def finish(obj, name, mat=None, bevel=0.0, smooth=False):
    obj.name = name
    if mat:
        obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("Soft manufactured edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    if smooth and hasattr(obj.data, "polygons"):
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    return obj


def cube(name, location, scale, mat, rotation=(0.0, 0.0, 0.0), bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, bevel)


def sphere(name, location, scale, mat, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, smooth=True)


def ico(name, location, scale, mat, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, location=location)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, smooth=False)


def cylinder(name, location, radius, depth, mat, rotation=(0.0, 0.0, 0.0), vertices=20, bevel=0.04):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    return finish(bpy.context.object, name, mat, bevel)


def cone(name, location, radius1, radius2, depth, mat, rotation=(0.0, 0.0, 0.0), vertices=8, bevel=0.02):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=location, rotation=rotation)
    return finish(bpy.context.object, name, mat, bevel)


def torus(name, location, major, minor, mat, rotation=(0.0, 0.0, 0.0), major_segments=32, minor_segments=8):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=major_segments,
        minor_segments=minor_segments,
        location=location,
        rotation=rotation,
    )
    return finish(bpy.context.object, name, mat, smooth=True)


def new_collection(name):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(objects, collection):
    for obj in objects:
        for owner in list(obj.users_collection):
            owner.objects.unlink(obj)
        collection.objects.link(obj)


def export_model(filename, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path = OUT / filename
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )
    print(f"Exported {path.name}: {path.stat().st_size} bytes, {len(objects)} objects")


def build_drone(mats):
    objects = []
    objects.append(sphere("Drone_Fuselage", (0, 0, 0.05), (0.72, 1.15, 0.43), mats["shell"]))
    objects.append(sphere("Drone_Canopy", (0, -0.38, 0.34), (0.48, 0.62, 0.25), mats["glass"], 24, 10))
    objects.append(cube("Drone_Wing_L", (-0.92, 0.12, -0.03), (0.78, 0.42, 0.09), mats["violet"], rotation=(0.0, 0.0, -0.13), bevel=0.13))
    objects.append(cube("Drone_Wing_R", (0.92, 0.12, -0.03), (0.78, 0.42, 0.09), mats["violet"], rotation=(0.0, 0.0, 0.13), bevel=0.13))
    objects.append(cube("Drone_Tail", (0, 0.9, 0.25), (0.1, 0.45, 0.43), mats["cyan"], rotation=(0.13, 0.0, 0.0), bevel=0.08))
    objects.append(torus("Drone_ReactorRing", (0, 0.28, 0.0), 0.78, 0.055, mats["cyan"], rotation=(math.pi / 2, 0, 0), major_segments=32))
    for x in (-0.68, 0.68):
        objects.append(cylinder(f"Drone_Engine_{'L' if x < 0 else 'R'}", (x, 0.62, -0.12), 0.2, 0.55, mats["dark"], rotation=(math.pi / 2, 0, 0), vertices=16, bevel=0.05))
        objects.append(cylinder(f"Drone_Thruster_{'L' if x < 0 else 'R'}", (x, 0.93, -0.12), 0.14, 0.08, mats["hot"], rotation=(math.pi / 2, 0, 0), vertices=16, bevel=0.02))
    objects.append(cone("Drone_Nose", (0, -1.15, 0.0), 0.42, 0.06, 0.75, mats["shell"], rotation=(math.pi / 2, 0, 0), vertices=12, bevel=0.05))
    objects.append(cylinder("Drone_Antenna", (0, -0.05, 0.75), 0.035, 0.55, mats["dark"], vertices=10, bevel=0.01))
    objects.append(ico("Drone_AntennaLight", (0, -0.05, 1.05), (0.12, 0.12, 0.12), mats["hot"], 2))
    return objects


def build_shard(mats):
    objects = []
    objects.append(cone("Shard_CoreTop", (0, 0, 0.48), 0.5, 0.04, 1.15, mats["cyan"], vertices=6, bevel=0.03))
    objects.append(cone("Shard_CoreBottom", (0, 0, -0.48), 0.5, 0.04, 1.15, mats["cyan"], rotation=(math.pi, 0, 0), vertices=6, bevel=0.03))
    for index, (angle, z) in enumerate(((0.0, 0.0), (2.1, -0.1), (4.2, 0.12))):
        objects.append(cone(
            f"Shard_Satellite_{index}",
            (math.cos(angle) * 0.62, math.sin(angle) * 0.62, z),
            0.18,
            0.02,
            0.72,
            mats["violet"],
            rotation=(0.28, math.sin(angle) * 0.25, angle),
            vertices=5,
            bevel=0.02,
        ))
    objects.append(torus("Shard_Halo", (0, 0, 0), 0.78, 0.045, mats["hot"], major_segments=28, minor_segments=6))
    return objects


def build_sentinel(mats):
    objects = []
    objects.append(ico("Sentinel_Core", (0, 0, 0), (0.62, 0.62, 0.62), mats["danger"], 2))
    objects.append(sphere("Sentinel_Eye", (0, -0.58, 0.05), (0.28, 0.1, 0.2), mats["hot"], 18, 8))
    objects.append(torus("Sentinel_Cage", (0, 0, 0), 0.9, 0.09, mats["violet"], rotation=(math.pi / 2, 0, 0), major_segments=24))
    for index in range(6):
        angle = math.tau * index / 6
        x, y = math.cos(angle) * 1.0, math.sin(angle) * 1.0
        objects.append(cone(f"Sentinel_Spike_{index}", (x, y, 0), 0.18, 0.02, 0.75, mats["danger"], rotation=(0, math.pi / 2, angle), vertices=6, bevel=0.02))
    return objects


def build_portal(mats):
    objects = []
    objects.append(torus("Portal_InnerEnergy", (0, 0, 0), 1.25, 0.11, mats["cyan"], rotation=(math.pi / 2, 0, 0), major_segments=40))
    objects.append(torus("Portal_OuterFrame", (0, 0, 0), 1.62, 0.18, mats["dark"], rotation=(math.pi / 2, 0, 0), major_segments=40, minor_segments=10))
    for index in range(12):
        angle = math.tau * index / 12
        objects.append(cube(
            f"Portal_Module_{index:02d}",
            (math.cos(angle) * 1.62, 0, math.sin(angle) * 1.62),
            (0.16, 0.2, 0.32),
            mats["violet"] if index % 2 else mats["cyan"],
            rotation=(0, -angle, 0),
            bevel=0.07,
        ))
    objects.append(cylinder("Portal_Base", (0, 0, -1.78), 0.72, 0.42, mats["shell"], vertices=16, bevel=0.1))
    return objects


def build_jump_pad(mats):
    objects = []
    objects.append(cylinder("JumpPad_Base", (0, 0, 0.1), 1.05, 0.22, mats["dark"], vertices=20, bevel=0.08))
    objects.append(cylinder("JumpPad_Energy", (0, 0, 0.24), 0.78, 0.08, mats["cyan"], vertices=20, bevel=0.03))
    objects.append(torus("JumpPad_Ring", (0, 0, 0.3), 0.8, 0.07, mats["hot"], major_segments=28, minor_segments=6))
    for y in (-0.28, 0.0, 0.28):
        objects.append(cube(f"JumpPad_Arrow_{y}", (0, y, 0.36), (0.13, 0.18, 0.025), mats["hot"], rotation=(0, 0, math.pi / 4), bevel=0.02))
    return objects


def build_platform(mats):
    objects = []
    objects.append(cube("Platform_Main", (0, 0, 0), (1.9, 1.9, 0.22), mats["shell"], bevel=0.14))
    objects.append(cube("Platform_Inlay", (0, 0, 0.25), (1.55, 1.55, 0.035), mats["dark"], bevel=0.07))
    for index, (x, y) in enumerate(((-1.55, -1.55), (1.55, -1.55), (-1.55, 1.55), (1.55, 1.55))):
        objects.append(cylinder(f"Platform_Light_{index}", (x, y, 0.31), 0.15, 0.08, mats["cyan"], vertices=12, bevel=0.02))
    objects.append(cube("Platform_LineX", (0, 0, 0.32), (1.25, 0.035, 0.02), mats["violet"], bevel=0.01))
    objects.append(cube("Platform_LineY", (0, 0, 0.32), (0.035, 1.25, 0.02), mats["violet"], bevel=0.01))
    return objects


def build_beacon(mats):
    objects = []
    objects.append(cylinder("Beacon_Base", (0, 0, 0.18), 0.62, 0.36, mats["dark"], vertices=16, bevel=0.08))
    objects.append(cylinder("Beacon_Stem", (0, 0, 0.85), 0.16, 1.25, mats["shell"], vertices=12, bevel=0.04))
    objects.append(ico("Beacon_Core", (0, 0, 1.65), (0.42, 0.42, 0.55), mats["hot"], 2))
    objects.append(torus("Beacon_Halo", (0, 0, 1.65), 0.62, 0.055, mats["violet"], major_segments=24, minor_segments=6))
    for index in range(3):
        angle = math.tau * index / 3
        objects.append(cube(f"Beacon_Fin_{index}", (math.cos(angle) * 0.42, math.sin(angle) * 0.42, 0.6), (0.08, 0.32, 0.42), mats["violet"], rotation=(0, 0, angle), bevel=0.04))
    return objects


def main():
    clear_scene()
    mats = {
        "shell": material("Aurora Alloy", (0.08, 0.18, 0.42, 1), 0.7, 0.2),
        "dark": material("Midnight Metal", (0.015, 0.025, 0.08, 1), 0.85, 0.18),
        "glass": material("Polarized Canopy", (0.12, 0.55, 0.9, 1), 0.35, 0.1, 0.45),
        "cyan": material("Aurora Cyan", (0.08, 0.95, 0.78, 1), 0.25, 0.18, 4.0),
        "violet": material("Aurora Violet", (0.55, 0.18, 1.0, 1), 0.3, 0.2, 2.6),
        "hot": material("Energy White", (0.65, 0.95, 1.0, 1), 0.05, 0.12, 6.0),
        "danger": material("Hazard Magenta", (1.0, 0.05, 0.3, 1), 0.35, 0.2, 3.4),
    }

    builders = [
        ("aurora_drone.glb", "AuroraDrone", build_drone),
        ("aurora_shard.glb", "AuroraShard", build_shard),
        ("energy_sentinel.glb", "EnergySentinel", build_sentinel),
        ("exit_portal.glb", "ExitPortal", build_portal),
        ("jump_pad.glb", "JumpPad", build_jump_pad),
        ("moving_platform.glb", "MovingPlatform", build_platform),
        ("switch_beacon.glb", "SwitchBeacon", build_beacon),
    ]

    all_objects = []
    for filename, collection_name, builder in builders:
        collection = new_collection(collection_name)
        objects = builder(mats)
        move_to_collection(objects, collection)
        export_model(filename, objects)
        all_objects.extend(objects)

    bpy.context.scene["asset_pack"] = "Aurora Drift 3D"
    bpy.context.scene["generator"] = "tools/generate_models.py"
    bpy.context.scene["blender_version"] = bpy.app.version_string
    bpy.context.scene["license"] = "Original project assets"
    blend_path = SOURCE_OUT / "aurora_assets.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), compress=True)
    print(f"Saved source {blend_path.name}: {blend_path.stat().st_size} bytes")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Convert Aurora Strike's original Blender GLB exports to Unity-friendly OBJ files.

The source of truth remains assets/blender/aurora_strike_assets.blend. This small,
dependency-free converter exists because Unity Build Automation workers do not ship
Blender and Unity does not import GLB without an additional package.
"""
from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "game" / "models"
DESTINATION = ROOT / "unity-probe" / "Assets" / "Resources" / "Models"
ASSETS = ("ak47", "m4a1", "awp", "glock")

COMPONENT_FORMAT = {
    5120: "b",  # BYTE
    5121: "B",  # UNSIGNED_BYTE
    5122: "h",  # SHORT
    5123: "H",  # UNSIGNED_SHORT
    5125: "I",  # UNSIGNED_INT
    5126: "f",  # FLOAT
}
TYPE_SIZE = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def identity():
    return [1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0]


def multiply(a, b):
    result = [0.0] * 16
    for row in range(4):
        for col in range(4):
            result[row * 4 + col] = sum(a[row * 4 + k] * b[k * 4 + col] for k in range(4))
    return result


def node_matrix(node):
    if "matrix" in node:
        source = node["matrix"]
        # glTF matrices are column-major; internal matrices are row-major.
        return [source[col * 4 + row] for row in range(4) for col in range(4)]
    tx, ty, tz = node.get("translation", (0.0, 0.0, 0.0))
    sx, sy, sz = node.get("scale", (1.0, 1.0, 1.0))
    x, y, z, w = node.get("rotation", (0.0, 0.0, 0.0, 1.0))
    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    wx, wy, wz = w * x, w * y, w * z
    rotation = [
        1 - 2 * (yy + zz), 2 * (xy - wz), 2 * (xz + wy), 0,
        2 * (xy + wz), 1 - 2 * (xx + zz), 2 * (yz - wx), 0,
        2 * (xz - wy), 2 * (yz + wx), 1 - 2 * (xx + yy), 0,
        0, 0, 0, 1,
    ]
    scale = [sx, 0, 0, 0, 0, sy, 0, 0, 0, 0, sz, 0, 0, 0, 0, 1]
    translation = identity()
    translation[3], translation[7], translation[11] = tx, ty, tz
    return multiply(translation, multiply(rotation, scale))


def transform_point(matrix, value):
    x, y, z = value
    return (
        matrix[0] * x + matrix[1] * y + matrix[2] * z + matrix[3],
        matrix[4] * x + matrix[5] * y + matrix[6] * z + matrix[7],
        matrix[8] * x + matrix[9] * y + matrix[10] * z + matrix[11],
    )


def transform_normal(matrix, value):
    # Aurora assets have uniform object scale. Rotation followed by normalization
    # is therefore sufficient and avoids a matrix dependency.
    x, y, z = value
    result = (
        matrix[0] * x + matrix[1] * y + matrix[2] * z,
        matrix[4] * x + matrix[5] * y + matrix[6] * z,
        matrix[8] * x + matrix[9] * y + matrix[10] * z,
    )
    length = math.sqrt(sum(component * component for component in result)) or 1.0
    return tuple(component / length for component in result)


def load_glb(path):
    data = path.read_bytes()
    magic, version, total_length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or total_length != len(data):
        raise ValueError(f"Unsupported GLB header: {path}")
    offset = 12
    chunks = {}
    while offset < len(data):
        length, kind = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunks[kind] = data[offset:offset + length]
        offset += length
    document = json.loads(chunks[b"JSON"].decode("utf-8"))
    return document, chunks.get(b"BIN\x00", b"")


def read_accessor(document, binary, accessor_index):
    accessor = document["accessors"][accessor_index]
    view = document["bufferViews"][accessor["bufferView"]]
    component = COMPONENT_FORMAT[accessor["componentType"]]
    dimensions = TYPE_SIZE[accessor["type"]]
    component_size = struct.calcsize(component)
    element_size = component_size * dimensions
    stride = view.get("byteStride", element_size)
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    unpack = struct.Struct("<" + component * dimensions).unpack_from
    return [unpack(binary, offset + index * stride) for index in range(accessor["count"])]


def material_name(material, index):
    name = material.get("name", f"Material_{index}")
    safe = "".join(character if character.isalnum() or character in "_-" else "_" for character in name)
    return safe or f"Material_{index}"


def write_mtl(document, target):
    lines = ["# Aurora Strike Blender material conversion"]
    for index, material in enumerate(document.get("materials", [])):
        pbr = material.get("pbrMetallicRoughness", {})
        color = pbr.get("baseColorFactor", [0.7, 0.7, 0.7, 1.0])
        metallic = pbr.get("metallicFactor", 0.0)
        roughness = pbr.get("roughnessFactor", 0.6)
        lines.extend([
            f"newmtl {material_name(material, index)}",
            f"Kd {color[0]:.6f} {color[1]:.6f} {color[2]:.6f}",
            f"d {color[3]:.6f}",
            f"Ns {(1.0 - roughness) * 800.0 + 1.0:.3f}",
            f"Ks {metallic:.5f} {metallic:.5f} {metallic:.5f}",
            "illum 2",
            "",
        ])
    target.write_text("\n".join(lines), encoding="utf-8")


def convert(source, target):
    document, binary = load_glb(source)
    lines = [
        "# Aurora Strike original Blender asset converted from GLB",
        f"# Source: game/models/{source.name}",
        f"mtllib {target.stem}.mtl",
    ]
    vertex_offset = 1
    normal_offset = 1
    uv_offset = 1

    def visit(node_index, parent_matrix):
        nonlocal vertex_offset, normal_offset, uv_offset
        node = document["nodes"][node_index]
        matrix = multiply(parent_matrix, node_matrix(node))
        if "mesh" in node:
            mesh = document["meshes"][node["mesh"]]
            for primitive_index, primitive in enumerate(mesh["primitives"]):
                if primitive.get("mode", 4) != 4:
                    raise ValueError("Only triangle primitives are supported")
                attributes = primitive["attributes"]
                positions = read_accessor(document, binary, attributes["POSITION"])
                normals = read_accessor(document, binary, attributes["NORMAL"]) if "NORMAL" in attributes else []
                uvs = read_accessor(document, binary, attributes["TEXCOORD_0"]) if "TEXCOORD_0" in attributes else []
                indices = read_accessor(document, binary, primitive["indices"]) if "indices" in primitive else [(i,) for i in range(len(positions))]
                object_name = node.get("name", mesh.get("name", f"Object_{node_index}"))
                lines.append(f"o {object_name.replace(' ', '_')}_{primitive_index}")
                material_index = primitive.get("material", 0)
                if document.get("materials"):
                    lines.append(f"usemtl {material_name(document['materials'][material_index], material_index)}")
                for position in positions:
                    x, y, z = transform_point(matrix, position)
                    lines.append(f"v {x:.7f} {y:.7f} {z:.7f}")
                for uv in uvs:
                    lines.append(f"vt {uv[0]:.7f} {uv[1]:.7f}")
                for normal in normals:
                    x, y, z = transform_normal(matrix, normal)
                    lines.append(f"vn {x:.7f} {y:.7f} {z:.7f}")
                for triangle_start in range(0, len(indices), 3):
                    triangle = [indices[triangle_start + corner][0] for corner in range(3)]
                    entries = []
                    # Preserve standard OBJ counter-clockwise winding. Unity's
                    # ModelImporter performs its own scene-coordinate conversion.
                    for index in triangle:
                        vertex = vertex_offset + index
                        uv = uv_offset + index if uvs else ""
                        normal = normal_offset + index if normals else ""
                        entries.append(f"{vertex}/{uv}/{normal}")
                    lines.append("f " + " ".join(entries))
                vertex_offset += len(positions)
                normal_offset += len(normals)
                uv_offset += len(uvs)
        for child in node.get("children", []):
            visit(child, matrix)

    scene_index = document.get("scene", 0)
    for root_node in document["scenes"][scene_index]["nodes"]:
        visit(root_node, identity())
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    write_mtl(document, target.with_suffix(".mtl"))
    print(f"Converted {source.name} -> {target.relative_to(ROOT)}")


def main():
    DESTINATION.mkdir(parents=True, exist_ok=True)
    assets = tuple(sys.argv[1:]) or ASSETS
    for name in assets:
        convert(SOURCE / f"{name}.glb", DESTINATION / f"{name}.obj")


if __name__ == "__main__":
    main()

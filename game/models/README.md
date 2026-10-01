# Generated Aurora Strike models

This directory is populated by `.github/workflows/generate-blender-models.yml` from the original procedural source in `tools/generate_shooter_models.py`.

Expected exports:

- twelve weapon GLBs (`ak47`, `m4a1`, `awp`, `scout`, `mp5`, `p90`, `nova_shotgun`, `deagle`, `glock`, `usp`, `knife`, `grenade`);
- `tactical_operator.glb`;
- `cargo_container.glb`;
- `cover_crate.glb`.

The Godot code includes lightweight fallback meshes so source-only validation remains possible before CI commits the generated models. Production Android builds require the generated asset set. The initial 15-asset launch gallery was generated and validated successfully with Blender 4.3.2 before the Android production export.

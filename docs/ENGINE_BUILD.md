# Engine build provenance

Aurora Strike is pinned to **Godot 4.7.2-stable**, the latest stable Godot release selected on 2026-10-01. It no longer relies on the old `barichello/godot-ci:4.3` editor or its prebuilt Android templates.

The workflow in `.github/workflows/build-godot-source-android.yml` performs a clean, reproducible build:

1. clones `https://github.com/godotengine/godot.git` at tag `4.7.2-stable`;
2. records the exact upstream commit;
3. installs SCons and the Android NDK r28b toolchain;
4. compiles the Linux editor from source;
5. compiles an arm64 Android debug export template from the same source revision;
6. imports and runtime-tests the real 5v5 game with that editor;
7. exports, verifies, checksums, and publishes the APK;
8. attaches the engine version and source provenance beside the APK.

The source revision is never vendored into this repository. The official upstream tag and exact commit are recorded in each release artifact.

## Why this route

Unity's complete native engine/editor is proprietary and is not available here as a public source checkout. Unreal Engine source access requires an Epic-authorized private GitHub checkout and acceptance of Epic's license. Godot is fully available from a public source tag and can therefore be compiled and audited in CI without private credentials.

## Upstream references

- Godot release: https://github.com/godotengine/godot/releases/tag/4.7.2-stable
- Godot 4.7 Android compilation: https://docs.godotengine.org/en/4.7/engine_details/development/compiling/compiling_for_android.html
- Godot 4.7 Linux compilation: https://docs.godotengine.org/en/4.7/engine_details/development/compiling/compiling_for_linuxbsd.html

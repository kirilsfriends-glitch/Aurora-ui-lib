using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class BuildProbe
{
    private const string ScenePath = "Assets/EngineProbe.unity";
    private const string OutputPath = "Build/AuroraUnityEngineProbe.apk";

    // Optional Unity Build Automation hook. Set the target's Pre-Export Method to
    // BuildProbe.PreExport if cloud-side project settings need to be repaired.
    public static void PreExport()
    {
        if (!File.Exists(ScenePath))
            throw new FileNotFoundException("The committed probe scene is missing.", ScenePath);

        EditorBuildSettings.scenes = new[]
        {
            new EditorBuildSettingsScene(ScenePath, true)
        };

        PlayerSettings.productName = "Aurora Unity Engine Probe";
        PlayerSettings.companyName = "Arena.ai";
        PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "ai.arena.aurorastrike");
        AssetDatabase.SaveAssets();
        Debug.Log("UNITY_PROBE_PREEXPORT_READY scene=" + ScenePath);
    }

    public static void BuildAndroid()
    {
        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

        var cameraObject = new GameObject("Probe Camera");
        var camera = cameraObject.AddComponent<Camera>();
        cameraObject.transform.position = new Vector3(0f, 1.5f, -5f);
        cameraObject.transform.LookAt(new Vector3(0f, 0.8f, 0f));
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(0.01f, 0.03f, 0.05f);

        var lightObject = new GameObject("Probe Light");
        var light = lightObject.AddComponent<Light>();
        light.type = LightType.Directional;
        light.intensity = 1.25f;
        lightObject.transform.rotation = Quaternion.Euler(45f, -35f, 0f);

        var cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
        cube.name = "Unity Android Toolchain Probe";
        cube.transform.position = new Vector3(0f, 0.8f, 0f);
        cube.transform.localScale = new Vector3(1.6f, 1.6f, 1.6f);
        var material = new Material(Shader.Find("Standard"));
        material.color = new Color(0.05f, 0.65f, 0.9f);
        cube.GetComponent<Renderer>().sharedMaterial = material;

        EditorSceneManager.SaveScene(scene, ScenePath);
        Directory.CreateDirectory("Build");

        PreExport();
        PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
        PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
        PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);

        if (!EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android))
            throw new Exception("Could not switch Unity to the Android build target.");

        var options = new BuildPlayerOptions
        {
            scenes = new[] { ScenePath },
            locationPathName = OutputPath,
            target = BuildTarget.Android,
            options = BuildOptions.Development
        };

        var report = BuildPipeline.BuildPlayer(options);
        if (report.summary.result != BuildResult.Succeeded)
            throw new Exception($"Unity Android probe failed: {report.summary.result}; errors={report.summary.totalErrors}");

        if (!File.Exists(OutputPath) || new FileInfo(OutputPath).Length == 0)
            throw new Exception("Unity reported success but did not produce a non-empty APK.");

        Debug.Log($"UNITY_ANDROID_PROBE_SUCCEEDED path={OutputPath} size={report.summary.totalSize}");
    }
}

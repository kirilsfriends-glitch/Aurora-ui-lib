using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class BuildProbe
{
    [MenuItem("Aurora/Build Android Probe")]
    public static void BuildAndroid()
    {
        const string scenePath = "Assets/EngineProbe.unity";
        const string outputPath = "Build/AuroraUnityEngineProbe.apk";

        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        var cameraObject = new GameObject("Probe Camera");
        var camera = cameraObject.AddComponent<Camera>();
        cameraObject.transform.position = new Vector3(0f, 1.4f, -5f);
        cameraObject.transform.LookAt(Vector3.up);
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(0.015f, 0.035f, 0.05f);

        var lightObject = new GameObject("Probe Light");
        var light = lightObject.AddComponent<Light>();
        light.type = LightType.Directional;
        light.intensity = 1.25f;
        lightObject.transform.rotation = Quaternion.Euler(45f, -35f, 0f);

        var cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
        cube.name = "Unity Android Toolchain Probe";
        cube.transform.position = Vector3.up;
        cube.transform.localScale = new Vector3(2f, 2f, 2f);

        EditorSceneManager.SaveScene(scene, scenePath);
        Directory.CreateDirectory("Build");

        PlayerSettings.productName = "Aurora Unity Engine Probe";
        PlayerSettings.companyName = "Arena.ai";
        PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.Android, "ai.arena.aurora.unityprobe");
        PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
        PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;

        var options = new BuildPlayerOptions
        {
            scenes = new[] { scenePath },
            locationPathName = outputPath,
            target = BuildTarget.Android,
            options = BuildOptions.Development
        };

        var report = BuildPipeline.BuildPlayer(options);
        if (report.summary.result != BuildResult.Succeeded)
        {
            throw new Exception($"Unity Android probe failed: {report.summary.result}, {report.summary.totalErrors} errors");
        }

        Debug.Log($"UNITY_ANDROID_PROBE_SUCCEEDED path={outputPath} size={report.summary.totalSize}");
    }
}

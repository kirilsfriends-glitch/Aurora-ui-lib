using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

public static class BuildProbe
{
    private const string ScenePath = "Assets/AuroraStrike.unity";
    private const string OutputPath = "Build/AuroraStrikeMobile.apk";

    // Optional Unity Build Automation hook. The committed build settings already
    // include the game scene, but this hook can repair cloud-side overrides.
    public static void PreExport()
    {
        if (!File.Exists(ScenePath))
            throw new FileNotFoundException("The committed Aurora Strike scene is missing.", ScenePath);

        EditorBuildSettings.scenes = new[]
        {
            new EditorBuildSettingsScene(ScenePath, true)
        };

        PlayerSettings.productName = "Aurora Strike Mobile";
        PlayerSettings.companyName = "Arena.ai";
        PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "ai.arena.aurorastrike");
        AssetDatabase.SaveAssets();
        Debug.Log("AURORA_STRIKE_PREEXPORT_READY scene=" + ScenePath);
    }

    public static void BuildAndroid()
    {
        Directory.CreateDirectory("Build");
        PreExport();
        PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
        PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
        PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);

        if (!EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android))
            throw new Exception("Could not switch Unity to the Android build target.");

        BuildPlayerOptions options = new BuildPlayerOptions
        {
            scenes = new[] { ScenePath },
            locationPathName = OutputPath,
            target = BuildTarget.Android,
            options = BuildOptions.Development
        };

        BuildReport report = BuildPipeline.BuildPlayer(options);
        if (report.summary.result != BuildResult.Succeeded)
            throw new Exception("Unity Android build failed: " + report.summary.result + "; errors=" + report.summary.totalErrors);

        if (!File.Exists(OutputPath) || new FileInfo(OutputPath).Length == 0)
            throw new Exception("Unity reported success but did not produce a non-empty APK.");

        Debug.Log("AURORA_STRIKE_ANDROID_SUCCEEDED path=" + OutputPath + " size=" + report.summary.totalSize);
    }
}

using UnityEngine;

public sealed class AuroraBootstrap : MonoBehaviour
{
    [SerializeField] private Shader mobileLitShader;

    private void Awake()
    {
        Application.targetFrameRate = 60;
        QualitySettings.vSyncCount = 0;
        QualitySettings.antiAliasing = 2;
        QualitySettings.shadowDistance = 42f;
        QualitySettings.pixelLightCount = 2;
        Screen.sleepTimeout = SleepTimeout.NeverSleep;
        Screen.orientation = ScreenOrientation.AutoRotation;
        Screen.autorotateToPortrait = false;
        Screen.autorotateToPortraitUpsideDown = false;
        Screen.autorotateToLandscapeLeft = true;
        Screen.autorotateToLandscapeRight = true;

        GameObject gameObject = new GameObject("Aurora Strike Mobile");
        AuroraGame game = gameObject.AddComponent<AuroraGame>();
        game.Initialize(mobileLitShader);
    }
}

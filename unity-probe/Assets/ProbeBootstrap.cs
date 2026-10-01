using UnityEngine;

public sealed class ProbeBootstrap : MonoBehaviour
{
    private Transform rotatingTarget;

    private void Awake()
    {
        Application.targetFrameRate = 60;

        var cameraObject = new GameObject("Main Camera");
        cameraObject.tag = "MainCamera";
        var camera = cameraObject.AddComponent<Camera>();
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(0.008f, 0.025f, 0.045f);
        cameraObject.transform.position = new Vector3(0f, 1.6f, -5f);
        cameraObject.transform.LookAt(new Vector3(0f, 0.8f, 0f));

        var lightObject = new GameObject("Directional Light");
        var light = lightObject.AddComponent<Light>();
        light.type = LightType.Directional;
        light.intensity = 1.35f;
        light.color = new Color(0.72f, 0.86f, 1f);
        lightObject.transform.rotation = Quaternion.Euler(42f, -32f, 0f);

        var cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
        cube.name = "Aurora Unity Cloud Probe";
        cube.transform.position = new Vector3(0f, 0.9f, 0f);
        cube.transform.localScale = new Vector3(1.7f, 1.7f, 1.7f);
        var material = new Material(Shader.Find("Standard"));
        material.color = new Color(0.02f, 0.58f, 0.88f);
        cube.GetComponent<Renderer>().sharedMaterial = material;
        rotatingTarget = cube.transform;

        var floor = GameObject.CreatePrimitive(PrimitiveType.Plane);
        floor.name = "Probe Floor";
        floor.transform.localScale = new Vector3(2f, 1f, 2f);
        var floorMaterial = new Material(Shader.Find("Standard"));
        floorMaterial.color = new Color(0.035f, 0.08f, 0.11f);
        floor.GetComponent<Renderer>().sharedMaterial = floorMaterial;
    }

    private void Update()
    {
        if (rotatingTarget != null)
            rotatingTarget.Rotate(18f * Time.deltaTime, 32f * Time.deltaTime, 7f * Time.deltaTime, Space.World);
    }
}

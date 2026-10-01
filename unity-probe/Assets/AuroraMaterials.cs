using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public sealed class AuroraMaterials
{
    private readonly Shader shader;
    private readonly Dictionary<string, Material> cache = new Dictionary<string, Material>();

    public AuroraMaterials(Shader mobileShader)
    {
        shader = mobileShader != null ? mobileShader : Shader.Find("Aurora/MobileLit");
        if (shader == null)
            throw new InvalidOperationException("Aurora/MobileLit shader was not included in the player build.");
    }

    public Material Get(string key, Color color, Color emission = default(Color), float smoothness = 0.3f)
    {
        Material material;
        if (cache.TryGetValue(key, out material))
            return material;
        material = new Material(shader) { name = "Aurora_" + key };
        material.SetColor("_Color", color);
        material.SetColor("_EmissionColor", emission);
        material.SetFloat("_Smoothness", smoothness);
        cache[key] = material;
        return material;
    }

    public Material Deck { get { return Get("Deck", new Color(0.31f, 0.37f, 0.40f), default(Color), 0.2f); } }
    public Material Concrete { get { return Get("Concrete", new Color(0.52f, 0.57f, 0.59f), default(Color), 0.18f); } }
    public Material WarehouseBlue { get { return Get("WarehouseBlue", new Color(0.20f, 0.40f, 0.50f), default(Color), 0.28f); } }
    public Material WarehouseWarm { get { return Get("WarehouseWarm", new Color(0.48f, 0.32f, 0.24f), default(Color), 0.25f); } }
    public Material ContainerBlue { get { return Get("ContainerBlue", new Color(0.06f, 0.38f, 0.53f), default(Color), 0.4f); } }
    public Material ContainerOrange { get { return Get("ContainerOrange", new Color(0.72f, 0.27f, 0.08f), default(Color), 0.32f); } }
    public Material ContainerGreen { get { return Get("ContainerGreen", new Color(0.18f, 0.43f, 0.31f), default(Color), 0.25f); } }
    public Material DarkMetal { get { return Get("DarkMetal", new Color(0.07f, 0.09f, 0.11f), default(Color), 0.7f); } }
    public Material Steel { get { return Get("Steel", new Color(0.38f, 0.43f, 0.47f), default(Color), 0.72f); } }
    public Material Safety { get { return Get("Safety", new Color(0.96f, 0.58f, 0.08f), new Color(0.06f, 0.025f, 0f), 0.3f); } }
    public Material Cyan { get { return Get("Cyan", new Color(0.06f, 0.70f, 0.84f), new Color(0.07f, 0.32f, 0.40f), 0.45f); } }
    public Material Red { get { return Get("Red", new Color(0.80f, 0.10f, 0.08f), new Color(0.20f, 0.01f, 0.01f), 0.38f); } }
    public Material BlueTeam { get { return Get("BlueTeam", new Color(0.05f, 0.40f, 0.78f), new Color(0.02f, 0.08f, 0.18f), 0.38f); } }
    public Material RedTeam { get { return Get("RedTeam", new Color(0.78f, 0.13f, 0.10f), new Color(0.16f, 0.015f, 0.01f), 0.38f); } }
    public Material Fabric { get { return Get("Fabric", new Color(0.15f, 0.18f, 0.16f), default(Color), 0.12f); } }
    public Material Armor { get { return Get("Armor", new Color(0.24f, 0.30f, 0.22f), default(Color), 0.3f); } }
    public Material Skin { get { return Get("Skin", new Color(0.55f, 0.36f, 0.25f), default(Color), 0.18f); } }
    public Material Glass { get { return Get("Glass", new Color(0.04f, 0.24f, 0.29f), new Color(0.01f, 0.08f, 0.12f), 0.86f); } }
    public Material Gunmetal { get { return Get("Gunmetal", new Color(0.08f, 0.10f, 0.12f), default(Color), 0.82f); } }
    public Material Polymer { get { return Get("Polymer", new Color(0.025f, 0.03f, 0.035f), default(Color), 0.2f); } }
    public Material Wood { get { return Get("Wood", new Color(0.36f, 0.13f, 0.045f), default(Color), 0.32f); } }

    public void ApplyWeaponPalette(GameObject root)
    {
        foreach (Renderer renderer in root.GetComponentsInChildren<Renderer>(true))
        {
            Material[] source = renderer.sharedMaterials;
            Material[] replacement = new Material[source.Length];
            for (int index = 0; index < replacement.Length; index++)
            {
                string name = source[index] != null ? source[index].name.ToLowerInvariant() : string.Empty;
                if (name.Contains("wood")) replacement[index] = Wood;
                else if (name.Contains("blue") || name.Contains("glass")) replacement[index] = Cyan;
                else if (name.Contains("steel")) replacement[index] = Steel;
                else if (name.Contains("polymer") || name.Contains("black")) replacement[index] = Polymer;
                else replacement[index] = Gunmetal;
            }
            renderer.sharedMaterials = replacement;
            renderer.shadowCastingMode = ShadowCastingMode.On;
            renderer.receiveShadows = true;
        }
    }

    public static GameObject CreateBox(string name, Transform parent, Vector3 position, Vector3 size, Material material, bool collider = true)
    {
        GameObject box = GameObject.CreatePrimitive(PrimitiveType.Cube);
        box.name = name;
        box.transform.SetParent(parent, false);
        box.transform.localPosition = position;
        box.transform.localScale = size;
        Renderer renderer = box.GetComponent<Renderer>();
        renderer.sharedMaterial = material;
        renderer.shadowCastingMode = ShadowCastingMode.Off;
        renderer.receiveShadows = true;
        if (!collider)
            UnityEngine.Object.Destroy(box.GetComponent<Collider>());
        return box;
    }

    public static GameObject CreateCylinder(string name, Transform parent, Vector3 position, Vector3 scale, Material material, bool collider = false)
    {
        GameObject cylinder = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        cylinder.name = name;
        cylinder.transform.SetParent(parent, false);
        cylinder.transform.localPosition = position;
        cylinder.transform.localScale = scale;
        Renderer renderer = cylinder.GetComponent<Renderer>();
        renderer.sharedMaterial = material;
        renderer.shadowCastingMode = ShadowCastingMode.Off;
        renderer.receiveShadows = true;
        if (!collider)
            UnityEngine.Object.Destroy(cylinder.GetComponent<Collider>());
        return cylinder;
    }

    public static void SetLayerRecursive(GameObject root, int layer)
    {
        root.layer = layer;
        foreach (Transform child in root.transform)
            SetLayerRecursive(child.gameObject, layer);
    }
}

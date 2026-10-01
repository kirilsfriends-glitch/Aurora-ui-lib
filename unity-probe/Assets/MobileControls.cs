using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public sealed class MobileControls : MonoBehaviour
{
    private enum TouchRole { None, Move, Look, Fire, Ads }

    public Vector2 Move { get; private set; }
    public bool FireHeld { get; private set; }
    public bool AdsHeld { get; private set; }
    public bool SettingsOpen { get; private set; }
    public float LookSensitivity { get; private set; }
    public bool InvertY { get; private set; }
    public bool AimAssist { get; private set; }

    private readonly Dictionary<int, TouchRole> touchRoles = new Dictionary<int, TouchRole>();
    private readonly Dictionary<RectTransform, Action> settingActions = new Dictionary<RectTransform, Action>();
    private RectTransform controlsRoot;
    private RectTransform moveArea;
    private RectTransform moveKnob;
    private RectTransform fireButton;
    private RectTransform adsButton;
    private RectTransform jumpButton;
    private RectTransform reloadButton;
    private RectTransform swapButton;
    private RectTransform settingsButton;
    private GameObject settingsPanel;
    private Text sensitivityValue;
    private Text scaleValue;
    private Text layoutValue;
    private Text aimValue;
    private Text invertValue;
    private Vector2 moveOriginScreen;
    private Vector2 lookDelta;
    private bool firePressed;
    private bool jumpPressed;
    private bool reloadPressed;
    private bool swapPressed;
    private int moveFinger = -1;
    private float controlScale;
    private int layoutMode;
    private Font font;
    private Sprite circleSprite;

    public void Build(Canvas canvas)
    {
        font = LoadFont();
        circleSprite = CreateCircleSprite();
        LookSensitivity = PlayerPrefs.GetFloat("aurora.lookSensitivity", 0.115f);
        controlScale = PlayerPrefs.GetFloat("aurora.controlScale", 1f);
        layoutMode = PlayerPrefs.GetInt("aurora.layoutMode", 0);
        AimAssist = PlayerPrefs.GetInt("aurora.aimAssist", 1) == 1;
        InvertY = PlayerPrefs.GetInt("aurora.invertY", 0) == 1;

        controlsRoot = CreateRect("Mobile FPS Controls", canvas.transform, Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero);
        Image rootImage = controlsRoot.gameObject.AddComponent<Image>();
        rootImage.color = Color.clear;
        rootImage.raycastTarget = false;

        moveArea = CreateControl("MOVE", controlsRoot, new Vector2(126f, 126f), 188f, new Color(0.06f, 0.40f, 0.62f, 0.40f), 20);
        moveKnob = CreateControl(string.Empty, moveArea, Vector2.zero, 70f, new Color(0.18f, 0.82f, 0.90f, 0.78f), 10);
        moveKnob.anchorMin = moveKnob.anchorMax = new Vector2(0.5f, 0.5f);
        moveKnob.anchoredPosition = Vector2.zero;

        fireButton = CreateControl("FIRE", controlsRoot, new Vector2(-116f, 180f), 142f, new Color(0.90f, 0.13f, 0.12f, 0.68f), 23);
        adsButton = CreateControl("ADS", controlsRoot, new Vector2(-260f, 108f), 94f, new Color(0.07f, 0.45f, 0.72f, 0.64f), 18);
        jumpButton = CreateControl("JUMP", controlsRoot, new Vector2(-266f, 235f), 98f, new Color(0.18f, 0.55f, 0.80f, 0.62f), 15);
        reloadButton = CreateControl("R", controlsRoot, new Vector2(-106f, 62f), 76f, new Color(0.08f, 0.17f, 0.27f, 0.72f), 21);
        swapButton = CreateControl("SWAP", controlsRoot, new Vector2(-380f, 70f), 82f, new Color(0.08f, 0.17f, 0.27f, 0.72f), 13);
        settingsButton = CreateControl("SET", canvas.transform, new Vector2(-58f, -58f), 74f, new Color(0.05f, 0.12f, 0.19f, 0.76f), 14);
        settingsButton.anchorMin = settingsButton.anchorMax = new Vector2(1f, 1f);

        BuildSettings(canvas);
        ApplyLayout();
    }

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Escape)) ToggleSettings();
        ProcessTouches();
    }

    private void ProcessTouches()
    {
        for (int index = 0; index < Input.touchCount; index++)
        {
            Touch touch = Input.GetTouch(index);
            if (touch.phase == TouchPhase.Began)
            {
                if (SettingsOpen)
                {
                    HandleSettingsTouch(touch.position);
                    touchRoles[touch.fingerId] = TouchRole.None;
                    continue;
                }
                if (Contains(settingsButton, touch.position))
                {
                    ToggleSettings();
                    touchRoles[touch.fingerId] = TouchRole.None;
                    continue;
                }

                TouchRole role = Classify(touch.position);
                if (role == TouchRole.Move && moveFinger != -1) role = TouchRole.Look;
                touchRoles[touch.fingerId] = role;
                if (role == TouchRole.Move)
                {
                    moveFinger = touch.fingerId;
                    moveOriginScreen = RectTransformUtility.WorldToScreenPoint(null, moveArea.position);
                    UpdateMove(touch.position);
                }
                else if (role == TouchRole.Fire)
                {
                    FireHeld = true;
                    firePressed = true;
                    Handheld.Vibrate();
                }
                else if (role == TouchRole.Ads) AdsHeld = true;
                else if (Contains(jumpButton, touch.position)) jumpPressed = true;
                else if (Contains(reloadButton, touch.position)) reloadPressed = true;
                else if (Contains(swapButton, touch.position)) swapPressed = true;
            }
            else if (touch.phase == TouchPhase.Moved || touch.phase == TouchPhase.Stationary)
            {
                TouchRole role;
                if (!touchRoles.TryGetValue(touch.fingerId, out role)) continue;
                if (role == TouchRole.Move) UpdateMove(touch.position);
                else if (role == TouchRole.Look && touch.phase == TouchPhase.Moved) lookDelta += touch.deltaPosition;
            }
            else if (touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled)
            {
                TouchRole role;
                if (touchRoles.TryGetValue(touch.fingerId, out role))
                {
                    touchRoles.Remove(touch.fingerId);
                    if (role == TouchRole.Move)
                    {
                        moveFinger = -1;
                        Move = Vector2.zero;
                        moveKnob.anchoredPosition = Vector2.zero;
                    }
                    else if (role == TouchRole.Fire) FireHeld = touchRoles.ContainsValue(TouchRole.Fire);
                    else if (role == TouchRole.Ads) AdsHeld = touchRoles.ContainsValue(TouchRole.Ads);
                }
            }
        }
    }

    private TouchRole Classify(Vector2 position)
    {
        // Buttons are checked before look. A touch anywhere else can rotate the
        // camera, but it can never shoot unless it began inside the FIRE control.
        if (Contains(fireButton, position)) return TouchRole.Fire;
        if (Contains(adsButton, position)) return TouchRole.Ads;
        if (Contains(jumpButton, position)) { jumpPressed = true; return TouchRole.None; }
        if (Contains(reloadButton, position)) { reloadPressed = true; return TouchRole.None; }
        if (Contains(swapButton, position)) { swapPressed = true; return TouchRole.None; }
        if (Contains(moveArea, position)) return TouchRole.Move;
        return TouchRole.Look;
    }

    private void UpdateMove(Vector2 screenPosition)
    {
        float radius = moveArea.rect.width * 0.39f;
        Vector2 raw = Vector2.ClampMagnitude((screenPosition - moveOriginScreen) / Mathf.Max(radius, 1f), 1f);
        Move = raw.magnitude < 0.12f ? Vector2.zero : raw * ((raw.magnitude - 0.12f) / 0.88f);
        moveKnob.anchoredPosition = raw * (moveArea.rect.width * 0.32f);
    }

    public Vector2 ConsumeLookDelta()
    {
        Vector2 result = lookDelta;
        lookDelta = Vector2.zero;
        return result;
    }

    public bool ConsumeFirePressed() { bool value = firePressed; firePressed = false; return value; }
    public bool ConsumeJumpPressed() { bool value = jumpPressed; jumpPressed = false; return value; }
    public bool ConsumeReloadPressed() { bool value = reloadPressed; reloadPressed = false; return value; }
    public bool ConsumeSwapPressed() { bool value = swapPressed; swapPressed = false; return value; }

    private void ToggleSettings()
    {
        SettingsOpen = !SettingsOpen;
        settingsPanel.SetActive(SettingsOpen);
        controlsRoot.gameObject.SetActive(!SettingsOpen);
        Time.timeScale = SettingsOpen ? 0f : 1f;
        ResetGameplayTouches();
        RefreshSettingsText();
    }

    private void ResetGameplayTouches()
    {
        touchRoles.Clear();
        moveFinger = -1;
        Move = Vector2.zero;
        FireHeld = false;
        AdsHeld = false;
        moveKnob.anchoredPosition = Vector2.zero;
    }

    private void BuildSettings(Canvas canvas)
    {
        settingsPanel = new GameObject("Control Settings");
        RectTransform panel = settingsPanel.AddComponent<RectTransform>();
        panel.SetParent(canvas.transform, false);
        panel.anchorMin = panel.anchorMax = new Vector2(0.5f, 0.5f);
        panel.sizeDelta = new Vector2(820f, 720f);
        Image background = settingsPanel.AddComponent<Image>();
        background.color = new Color(0.025f, 0.055f, 0.085f, 0.96f);
        AddText("CONTROLS", panel, new Vector2(0f, 292f), new Vector2(700f, 70f), 34, TextAnchor.MiddleCenter, Color.white);
        AddText("Only the FIRE button shoots. Drag empty space to look.", panel, new Vector2(0f, 242f), new Vector2(720f, 44f), 18, TextAnchor.MiddleCenter, new Color(0.60f, 0.82f, 0.90f));

        sensitivityValue = AddText("", panel, new Vector2(0f, 154f), new Vector2(380f, 54f), 23, TextAnchor.MiddleCenter, Color.white);
        AddSettingsAction("−", panel, new Vector2(-270f, 154f), delegate { LookSensitivity = Mathf.Max(0.055f, LookSensitivity - 0.01f); Save(); }, 74f);
        AddSettingsAction("+", panel, new Vector2(270f, 154f), delegate { LookSensitivity = Mathf.Min(0.24f, LookSensitivity + 0.01f); Save(); }, 74f);

        scaleValue = AddText("", panel, new Vector2(0f, 66f), new Vector2(380f, 54f), 23, TextAnchor.MiddleCenter, Color.white);
        AddSettingsAction("−", panel, new Vector2(-270f, 66f), delegate { controlScale = Mathf.Max(0.78f, controlScale - 0.05f); ApplyLayout(); Save(); }, 74f);
        AddSettingsAction("+", panel, new Vector2(270f, 66f), delegate { controlScale = Mathf.Min(1.28f, controlScale + 0.05f); ApplyLayout(); Save(); }, 74f);

        layoutValue = AddSettingsAction("", panel, new Vector2(0f, -30f), delegate { layoutMode = (layoutMode + 1) % 3; ApplyLayout(); Save(); }, 450f, 62f);
        aimValue = AddSettingsAction("", panel, new Vector2(0f, -110f), delegate { AimAssist = !AimAssist; Save(); }, 450f, 62f);
        invertValue = AddSettingsAction("", panel, new Vector2(0f, -190f), delegate { InvertY = !InvertY; Save(); }, 450f, 62f);
        AddSettingsAction("CLOSE & SAVE", panel, new Vector2(0f, -286f), ToggleSettings, 360f, 72f, new Color(0.05f, 0.55f, 0.68f, 0.92f));
        settingsPanel.SetActive(false);
    }

    private void HandleSettingsTouch(Vector2 position)
    {
        foreach (KeyValuePair<RectTransform, Action> entry in settingActions)
        {
            if (Contains(entry.Key, position))
            {
                entry.Value();
                RefreshSettingsText();
                return;
            }
        }
    }

    private void ApplyLayout()
    {
        bool leftHanded = layoutMode == 2;
        bool compact = layoutMode == 1;
        float size = controlScale * (compact ? 0.88f : 1f);
        controlsRoot.localScale = Vector3.one;

        SetCorner(moveArea, leftHanded ? new Vector2(1f, 0f) : new Vector2(0f, 0f),
            new Vector2((leftHanded ? -126f : 126f), 126f), 188f * size);
        SetCorner(fireButton, leftHanded ? new Vector2(0f, 0f) : new Vector2(1f, 0f),
            new Vector2(leftHanded ? 116f : -116f, 180f), 142f * size);
        SetCorner(adsButton, leftHanded ? new Vector2(0f, 0f) : new Vector2(1f, 0f),
            new Vector2(leftHanded ? 260f : -260f, 108f), 94f * size);
        SetCorner(jumpButton, leftHanded ? new Vector2(0f, 0f) : new Vector2(1f, 0f),
            new Vector2(leftHanded ? 266f : -266f, 235f), 98f * size);
        SetCorner(reloadButton, leftHanded ? new Vector2(0f, 0f) : new Vector2(1f, 0f),
            new Vector2(leftHanded ? 106f : -106f, 62f), 76f * size);
        SetCorner(swapButton, leftHanded ? new Vector2(0f, 0f) : new Vector2(1f, 0f),
            new Vector2(leftHanded ? 380f : -380f, 70f), 82f * size);
        RefreshSettingsText();
    }

    private void SetCorner(RectTransform rect, Vector2 anchor, Vector2 position, float size)
    {
        rect.anchorMin = rect.anchorMax = anchor;
        rect.pivot = anchor;
        rect.anchoredPosition = position;
        rect.sizeDelta = Vector2.one * size;
    }

    private void Save()
    {
        PlayerPrefs.SetFloat("aurora.lookSensitivity", LookSensitivity);
        PlayerPrefs.SetFloat("aurora.controlScale", controlScale);
        PlayerPrefs.SetInt("aurora.layoutMode", layoutMode);
        PlayerPrefs.SetInt("aurora.aimAssist", AimAssist ? 1 : 0);
        PlayerPrefs.SetInt("aurora.invertY", InvertY ? 1 : 0);
        PlayerPrefs.Save();
    }

    private void RefreshSettingsText()
    {
        if (sensitivityValue == null) return;
        sensitivityValue.text = "LOOK SENSITIVITY   " + Mathf.RoundToInt(LookSensitivity * 1000f);
        scaleValue.text = "BUTTON SIZE   " + Mathf.RoundToInt(controlScale * 100f) + "%";
        layoutValue.text = "LAYOUT   " + (layoutMode == 0 ? "CLASSIC" : layoutMode == 1 ? "COMPACT" : "LEFT-HANDED");
        aimValue.text = "AIM ASSIST   " + (AimAssist ? "ON" : "OFF");
        invertValue.text = "INVERT Y   " + (InvertY ? "ON" : "OFF");
    }

    private RectTransform CreateControl(string label, Transform parent, Vector2 position, float size, Color color, int fontSize)
    {
        RectTransform rect = CreateRect(label + " Control", parent, Vector2.zero, Vector2.zero, position, Vector2.one * size);
        Image image = rect.gameObject.AddComponent<Image>();
        image.sprite = circleSprite;
        image.color = color;
        image.raycastTarget = false;
        if (!string.IsNullOrEmpty(label))
            AddText(label, rect, Vector2.zero, Vector2.one * size, fontSize, TextAnchor.MiddleCenter, Color.white);
        return rect;
    }

    private Text AddSettingsAction(string label, Transform parent, Vector2 position, Action action, float width, float height = 74f, Color color = default(Color))
    {
        RectTransform rect = CreateRect(label + " Setting", parent, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), position, new Vector2(width, height));
        Image image = rect.gameObject.AddComponent<Image>();
        image.color = color == default(Color) ? new Color(0.08f, 0.20f, 0.29f, 0.94f) : color;
        image.raycastTarget = false;
        Text text = AddText(label, rect, Vector2.zero, rect.sizeDelta, 22, TextAnchor.MiddleCenter, Color.white);
        settingActions[rect] = action;
        return text;
    }

    private Text AddText(string value, Transform parent, Vector2 position, Vector2 size, int fontSize, TextAnchor alignment, Color color)
    {
        RectTransform rect = CreateRect(value + " Text", parent, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), position, size);
        Text text = rect.gameObject.AddComponent<Text>();
        text.font = font;
        text.text = value;
        text.fontSize = fontSize;
        text.alignment = alignment;
        text.color = color;
        text.raycastTarget = false;
        text.resizeTextForBestFit = false;
        return text;
    }

    private static RectTransform CreateRect(string objectName, Transform parent, Vector2 anchorMin, Vector2 anchorMax, Vector2 position, Vector2 size)
    {
        GameObject gameObject = new GameObject(objectName);
        RectTransform rect = gameObject.AddComponent<RectTransform>();
        rect.SetParent(parent, false);
        rect.anchorMin = anchorMin;
        rect.anchorMax = anchorMax;
        rect.pivot = new Vector2(0.5f, 0.5f);
        rect.anchoredPosition = position;
        rect.sizeDelta = size;
        return rect;
    }

    private static bool Contains(RectTransform rect, Vector2 screenPosition)
    {
        return rect != null && rect.gameObject.activeInHierarchy && RectTransformUtility.RectangleContainsScreenPoint(rect, screenPosition, null);
    }

    private static Font LoadFont()
    {
        Font loaded = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        if (loaded == null) loaded = Resources.GetBuiltinResource<Font>("Arial.ttf");
        return loaded;
    }

    private static Sprite CreateCircleSprite()
    {
        const int size = 64;
        Texture2D texture = new Texture2D(size, size, TextureFormat.RGBA32, false);
        Color[] pixels = new Color[size * size];
        Vector2 center = new Vector2((size - 1) * 0.5f, (size - 1) * 0.5f);
        for (int y = 0; y < size; y++)
        for (int x = 0; x < size; x++)
        {
            float distance = Vector2.Distance(new Vector2(x, y), center) / (size * 0.5f);
            float alpha = Mathf.Clamp01((1f - distance) * 16f);
            pixels[y * size + x] = new Color(1f, 1f, 1f, alpha);
        }
        texture.SetPixels(pixels);
        texture.Apply(false, true);
        return Sprite.Create(texture, new Rect(0f, 0f, size, size), new Vector2(0.5f, 0.5f), 100f);
    }
}

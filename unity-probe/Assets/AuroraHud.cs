using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public sealed class AuroraHud : MonoBehaviour
{
    public Canvas Canvas { get; private set; }

    private AuroraGame game;
    private Font font;
    private Text scoreText;
    private Text timerText;
    private Text healthText;
    private Text ammoText;
    private Text weaponText;
    private Text locationText;
    private Text announcementText;
    private Text killFeedText;
    private Image healthFill;
    private Image damageFlash;
    private readonly List<string> feed = new List<string>();
    private readonly List<Image> hitMarker = new List<Image>();
    private float announcementTimer;
    private float hitTimer;
    private float damageTimer;

    public void Build(AuroraGame gameManager)
    {
        game = gameManager;
        font = LoadFont();
        GameObject canvasObject = new GameObject("Aurora Strike HUD");
        Canvas = canvasObject.AddComponent<Canvas>();
        Canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        Canvas.sortingOrder = 10;
        CanvasScaler scaler = canvasObject.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1920f, 1080f);
        scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
        scaler.matchWidthOrHeight = 0.5f;
        canvasObject.AddComponent<GraphicRaycaster>();

        RectTransform root = CreateRect("HUD Root", Canvas.transform, Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero);
        damageFlash = AddImage("Damage Flash", root, Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero, new Color(0.8f, 0.02f, 0.01f, 0f));

        RectTransform topBar = CreatePanel("Score Bar", root, new Vector2(0.5f, 1f), new Vector2(0f, -44f), new Vector2(580f, 70f), new Color(0.02f, 0.07f, 0.11f, 0.84f));
        scoreText = AddText("ALPHA 0     0 BRAVO", topBar, new Vector2(0f, 8f), new Vector2(540f, 36f), 25, TextAnchor.MiddleCenter, Color.white);
        timerText = AddText("07:00", topBar, new Vector2(0f, -21f), new Vector2(220f, 28f), 18, TextAnchor.MiddleCenter, new Color(0.50f, 0.88f, 0.95f));

        locationText = AddText("DOCKYARD / DAY", root, new Vector2(30f, -30f), new Vector2(450f, 46f), 20, TextAnchor.UpperLeft, new Color(0.80f, 0.93f, 0.96f));
        locationText.rectTransform.anchorMin = locationText.rectTransform.anchorMax = new Vector2(0f, 1f);
        locationText.rectTransform.pivot = new Vector2(0f, 1f);

        RectTransform healthPanel = CreatePanel("Health Panel", root, new Vector2(0f, 0f), new Vector2(155f, 58f), new Vector2(250f, 72f), new Color(0.02f, 0.07f, 0.11f, 0.84f));
        healthText = AddText("HP 100", healthPanel, new Vector2(-65f, 10f), new Vector2(100f, 34f), 24, TextAnchor.MiddleLeft, Color.white);
        Image healthBack = AddImage("Health Back", healthPanel, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(54f, -17f), new Vector2(118f, 9f), new Color(0.08f, 0.12f, 0.14f, 1f));
        healthFill = AddImage("Health Fill", healthBack.rectTransform, new Vector2(0f, 0f), new Vector2(0f, 1f), Vector2.zero, Vector2.zero, new Color(0.13f, 0.82f, 0.68f, 1f));
        healthFill.rectTransform.pivot = new Vector2(0f, 0.5f);
        healthFill.rectTransform.sizeDelta = new Vector2(118f, 0f);

        RectTransform weaponPanel = CreatePanel("Weapon Panel", root, new Vector2(1f, 0f), new Vector2(-210f, 62f), new Vector2(330f, 86f), new Color(0.02f, 0.07f, 0.11f, 0.84f));
        weaponText = AddText("AK-47", weaponPanel, new Vector2(-88f, 16f), new Vector2(130f, 34f), 20, TextAnchor.MiddleLeft, new Color(0.55f, 0.90f, 0.96f));
        ammoText = AddText("30 / 90", weaponPanel, new Vector2(65f, 0f), new Vector2(170f, 56f), 31, TextAnchor.MiddleRight, Color.white);

        killFeedText = AddText("", root, new Vector2(-34f, -112f), new Vector2(620f, 180f), 18, TextAnchor.UpperRight, Color.white);
        killFeedText.rectTransform.anchorMin = killFeedText.rectTransform.anchorMax = new Vector2(1f, 1f);
        killFeedText.rectTransform.pivot = new Vector2(1f, 1f);

        announcementText = AddText("TEAM DEATHMATCH\nFIRST TO 30", root, new Vector2(0f, 160f), new Vector2(1000f, 150f), 34, TextAnchor.MiddleCenter, Color.white);
        announcementText.rectTransform.anchorMin = announcementText.rectTransform.anchorMax = new Vector2(0.5f, 0.5f);

        BuildCrosshair(root);
        RefreshPlayerStats();
    }

    private void Update()
    {
        if (game == null) return;
        scoreText.text = "<color=#5DE7F5>ALPHA " + game.AlphaScore + "</color>     <color=#FF7466>" + game.BravoScore + " BRAVO</color>";
        scoreText.supportRichText = true;
        int seconds = Mathf.Max(0, Mathf.CeilToInt(game.RemainingTime));
        timerText.text = (seconds / 60).ToString("00") + ":" + (seconds % 60).ToString("00");
        if (game.Player != null && game.Player.Actor != null)
        {
            float health = game.Player.Actor.Health;
            healthText.text = "HP " + Mathf.CeilToInt(health);
            healthFill.rectTransform.sizeDelta = new Vector2(118f * health / 100f, 0f);
            healthFill.color = health > 55f ? new Color(0.13f, 0.82f, 0.68f) : health > 25f ? new Color(0.95f, 0.65f, 0.10f) : new Color(0.92f, 0.12f, 0.10f);
            locationText.text = GetLocation(game.Player.transform.position) + "  /  DOCKYARD DAY";
        }

        if (announcementTimer > 0f)
        {
            announcementTimer -= Time.deltaTime;
            announcementText.color = new Color(1f, 1f, 1f, Mathf.Clamp01(announcementTimer * 2f));
        }
        else announcementText.text = string.Empty;

        hitTimer = Mathf.Max(0f, hitTimer - Time.deltaTime);
        foreach (Image line in hitMarker)
            line.color = new Color(line.color.r, line.color.g, line.color.b, Mathf.Clamp01(hitTimer * 9f));

        damageTimer = Mathf.Max(0f, damageTimer - Time.deltaTime);
        damageFlash.color = new Color(0.8f, 0.02f, 0.01f, Mathf.Clamp01(damageTimer) * 0.24f);
    }

    public void RefreshPlayerStats()
    {
        if (game == null || game.Player == null || game.Player.Weapon == null || game.Player.Weapon.Current == null) return;
        WeaponController weapon = game.Player.Weapon;
        weaponText.text = weapon.Current.DisplayName + (weapon.Reloading ? "  RELOADING" : string.Empty);
        ammoText.text = weapon.Ammo + " / " + weapon.Reserve;
    }

    public void ShowAnnouncement(string message, float duration)
    {
        announcementText.text = message;
        announcementText.color = Color.white;
        announcementTimer = duration;
    }

    public void ShowKill(CombatActor victim, CombatActor killer, bool headshot)
    {
        string killerName = killer != null ? killer.Callsign : "ENVIRONMENT";
        string line = killerName + "  " + (headshot ? "◆" : "›") + "  " + victim.Callsign;
        feed.Insert(0, line);
        while (feed.Count > 5) feed.RemoveAt(feed.Count - 1);
        killFeedText.text = string.Join("\n", feed.ToArray());
    }

    public void ShowHitMarker(bool headshot)
    {
        hitTimer = 0.18f;
        Color color = headshot ? new Color(1f, 0.30f, 0.16f, 1f) : Color.white;
        foreach (Image line in hitMarker) line.color = color;
    }

    public void ShowDamage(Vector3 localAttacker, float health)
    {
        damageTimer = health <= 0f ? 1.2f : 0.65f;
    }

    private void BuildCrosshair(RectTransform root)
    {
        Vector2[] positions = { new Vector2(0f, 13f), new Vector2(0f, -13f), new Vector2(13f, 0f), new Vector2(-13f, 0f) };
        Vector2[] sizes = { new Vector2(2.5f, 10f), new Vector2(2.5f, 10f), new Vector2(10f, 2.5f), new Vector2(10f, 2.5f) };
        for (int index = 0; index < positions.Length; index++)
        {
            Image line = AddImage("Crosshair", root, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), positions[index], sizes[index], new Color(0.78f, 0.98f, 1f, 0.92f));
        }
        for (int index = 0; index < 4; index++)
        {
            float x = index < 2 ? (index == 0 ? -9f : 9f) : (index == 2 ? -9f : 9f);
            float y = index < 2 ? (index == 0 ? -9f : 9f) : (index == 2 ? 9f : -9f);
            Image marker = AddImage("Hit Marker", root, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(x, y), new Vector2(2.5f, 12f), new Color(1f, 1f, 1f, 0f));
            marker.rectTransform.localRotation = Quaternion.Euler(0f, 0f, index < 2 ? -45f : 45f);
            hitMarker.Add(marker);
        }
    }

    private static string GetLocation(Vector3 position)
    {
        if (Mathf.Abs(position.x) < 8f && Mathf.Abs(position.z) < 7f) return "CUSTOMS";
        if (position.x < -20f) return "ALPHA YARD";
        if (position.x > 20f) return "BRAVO YARD";
        if (position.z < -8f) return "NORTH CONTAINERS";
        if (position.z > 8f) return "SOUTH CONTAINERS";
        return "MID LANES";
    }

    private RectTransform CreatePanel(string name, Transform parent, Vector2 anchor, Vector2 position, Vector2 size, Color color)
    {
        RectTransform rect = CreateRect(name, parent, anchor, anchor, position, size);
        Image image = rect.gameObject.AddComponent<Image>();
        image.color = color;
        image.raycastTarget = false;
        return rect;
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
        return text;
    }

    private static Image AddImage(string name, Transform parent, Vector2 anchorMin, Vector2 anchorMax, Vector2 position, Vector2 size, Color color)
    {
        RectTransform rect = CreateRect(name, parent, anchorMin, anchorMax, position, size);
        Image image = rect.gameObject.AddComponent<Image>();
        image.color = color;
        image.raycastTarget = false;
        return image;
    }

    private static RectTransform CreateRect(string name, Transform parent, Vector2 anchorMin, Vector2 anchorMax, Vector2 position, Vector2 size)
    {
        GameObject gameObject = new GameObject(name);
        RectTransform rect = gameObject.AddComponent<RectTransform>();
        rect.SetParent(parent, false);
        rect.anchorMin = anchorMin;
        rect.anchorMax = anchorMax;
        rect.pivot = new Vector2(0.5f, 0.5f);
        rect.anchoredPosition = position;
        rect.sizeDelta = size;
        return rect;
    }

    private static Font LoadFont()
    {
        Font loaded = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        if (loaded == null) loaded = Resources.GetBuiltinResource<Font>("Arial.ttf");
        return loaded;
    }
}

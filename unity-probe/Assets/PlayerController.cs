using UnityEngine;

public sealed class PlayerController : MonoBehaviour
{
    public Camera PlayerCamera { get; private set; }
    public CombatActor Actor { get; private set; }
    public WeaponController Weapon { get; private set; }

    private AuroraGame game;
    private CharacterController controller;
    private MobileControls controls;
    private Transform viewPivot;
    private Transform weaponMount;
    private float yaw;
    private float pitch;
    private float verticalVelocity;
    private float bobTime;
    private bool alive = true;
    private bool desktopFirePrevious;
    private int weaponIndex;

    public void Initialize(AuroraGame gameManager, int spawnIndex, string initialWeapon)
    {
        game = gameManager;
        gameObject.name = "Local Player";
        controller = gameObject.AddComponent<CharacterController>();
        controller.radius = 0.35f;
        controller.height = 1.78f;
        controller.center = new Vector3(0f, 0.89f, 0f);
        controller.stepOffset = 0.32f;
        controller.slopeLimit = 48f;
        controller.skinWidth = 0.045f;

        Transform aimPoint = new GameObject("Player Aim Point").transform;
        aimPoint.SetParent(transform, false);
        aimPoint.localPosition = new Vector3(0f, 1.45f, 0f);

        viewPivot = new GameObject("View Pivot").transform;
        viewPivot.SetParent(transform, false);
        viewPivot.localPosition = new Vector3(0f, 1.58f, 0f);
        GameObject cameraObject = new GameObject("FPS Camera");
        cameraObject.tag = "MainCamera";
        cameraObject.transform.SetParent(viewPivot, false);
        PlayerCamera = cameraObject.AddComponent<Camera>();
        PlayerCamera.fieldOfView = 74f;
        PlayerCamera.nearClipPlane = 0.035f;
        PlayerCamera.farClipPlane = 130f;
        PlayerCamera.clearFlags = CameraClearFlags.SolidColor;
        PlayerCamera.backgroundColor = new Color(0.38f, 0.67f, 0.86f);
        PlayerCamera.allowHDR = false;
        PlayerCamera.allowMSAA = true;

        weaponMount = new GameObject("First Person Weapon Mount").transform;
        weaponMount.SetParent(cameraObject.transform, false);
        weaponMount.localPosition = new Vector3(0.30f, -0.27f, 0.53f);
        weaponMount.localRotation = Quaternion.Euler(1.5f, -1.5f, 0f);
        BuildFirstPersonArms();

        Actor = gameObject.AddComponent<CombatActor>();
        Weapon = gameObject.AddComponent<WeaponController>();
        Actor.Initialize(game, 0, spawnIndex, "YOU", true, null, aimPoint);
        yaw = transform.eulerAngles.y;
        Weapon.Initialize(game, Actor, weaponMount, initialWeapon, true);
        Weapon.RecoilRequested += ApplyRecoil;
        Weapon.StatsChanged += OnWeaponStatsChanged;
        weaponIndex = FindWeaponIndex(initialWeapon);

        if (!Application.isMobilePlatform)
        {
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;
        }
    }

    public void SetControls(MobileControls mobileControls)
    {
        controls = mobileControls;
    }

    private void BuildFirstPersonArms()
    {
        Transform arms = new GameObject("Animated First Person Arms").transform;
        arms.SetParent(weaponMount, false);
        GameObject leftSleeve = AuroraMaterials.CreateCylinder("Left Sleeve", arms, new Vector3(-0.19f, -0.19f, -0.12f), new Vector3(0.09f, 0.24f, 0.09f), game.Materials.Armor, false);
        leftSleeve.transform.localRotation = Quaternion.Euler(-56f, 0f, -8f);
        GameObject rightSleeve = AuroraMaterials.CreateCylinder("Right Sleeve", arms, new Vector3(0.12f, -0.20f, -0.09f), new Vector3(0.09f, 0.25f, 0.09f), game.Materials.Fabric, false);
        rightSleeve.transform.localRotation = Quaternion.Euler(-60f, 0f, 10f);
        GameObject leftGlove = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        leftGlove.name = "Left Tactical Glove";
        leftGlove.transform.SetParent(arms, false);
        leftGlove.transform.localPosition = new Vector3(-0.10f, -0.03f, 0.16f);
        leftGlove.transform.localScale = new Vector3(0.15f, 0.12f, 0.18f);
        leftGlove.GetComponent<Renderer>().sharedMaterial = game.Materials.Polymer;
        Destroy(leftGlove.GetComponent<Collider>());
        GameObject rightGlove = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        rightGlove.name = "Right Tactical Glove";
        rightGlove.transform.SetParent(arms, false);
        rightGlove.transform.localPosition = new Vector3(0.08f, -0.04f, 0.27f);
        rightGlove.transform.localScale = new Vector3(0.15f, 0.12f, 0.18f);
        rightGlove.GetComponent<Renderer>().sharedMaterial = game.Materials.Polymer;
        Destroy(rightGlove.GetComponent<Collider>());
    }

    private void Update()
    {
        if (Actor == null || !alive || !Actor.Alive || game == null || !game.MatchActive)
            return;

        bool settingsOpen = controls != null && controls.SettingsOpen;
        UpdateLook(settingsOpen);
        UpdateMovement(settingsOpen);
        UpdateWeapon(settingsOpen);
    }

    private void UpdateLook(bool settingsOpen)
    {
        Vector2 look = Vector2.zero;
        float sensitivity = 0.11f;
        bool invertY = false;
        if (!settingsOpen && controls != null)
        {
            look += controls.ConsumeLookDelta();
            sensitivity = controls.LookSensitivity;
            invertY = controls.InvertY;
        }
        if (!Application.isMobilePlatform && !settingsOpen && Cursor.lockState == CursorLockMode.Locked)
        {
            look += new Vector2(Input.GetAxisRaw("Mouse X") * 7.5f, Input.GetAxisRaw("Mouse Y") * 7.5f);
            sensitivity = 0.12f;
        }

        yaw += look.x * sensitivity;
        pitch += look.y * sensitivity * (invertY ? 1f : -1f);
        pitch = Mathf.Clamp(pitch, -82f, 82f);
        transform.rotation = Quaternion.Euler(0f, yaw, 0f);
        viewPivot.localRotation = Quaternion.Euler(pitch, 0f, 0f);

        if (!Application.isMobilePlatform && Input.GetKeyDown(KeyCode.Escape))
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }
    }

    private void UpdateMovement(bool settingsOpen)
    {
        Vector2 input = settingsOpen ? Vector2.zero : (controls != null ? controls.Move : Vector2.zero);
        if (!Application.isMobilePlatform && !settingsOpen)
        {
            input.x = (Input.GetKey(KeyCode.D) ? 1f : 0f) - (Input.GetKey(KeyCode.A) ? 1f : 0f);
            input.y = (Input.GetKey(KeyCode.W) ? 1f : 0f) - (Input.GetKey(KeyCode.S) ? 1f : 0f);
            input = Vector2.ClampMagnitude(input, 1f);
        }

        bool aiming = controls != null && controls.AdsHeld;
        if (!Application.isMobilePlatform) aiming |= Input.GetMouseButton(1);
        Vector3 wish = (transform.right * input.x + transform.forward * input.y);
        float speed = 6.5f * (Weapon.Current != null ? Weapon.Current.MoveMultiplier : 1f) * (aiming ? 0.72f : 1f);
        bool grounded = controller.isGrounded;
        if (grounded && verticalVelocity < 0f) verticalVelocity = -1.2f;
        bool jump = controls != null && controls.ConsumeJumpPressed();
        if (!Application.isMobilePlatform) jump |= Input.GetKeyDown(KeyCode.Space);
        if (!settingsOpen && grounded && jump) verticalVelocity = 7.4f;
        verticalVelocity -= 21f * Time.deltaTime;
        controller.Move((wish * speed + Vector3.up * verticalVelocity) * Time.deltaTime);

        float movement = new Vector2(controller.velocity.x, controller.velocity.z).magnitude;
        bobTime += Time.deltaTime * Mathf.Lerp(2f, 10f, movement / 6f);
        float bob = grounded ? Mathf.Sin(bobTime) * Mathf.Min(0.035f, movement * 0.006f) : 0f;
        viewPivot.localPosition = Vector3.Lerp(viewPivot.localPosition, new Vector3(0f, 1.58f + bob, 0f), Time.deltaTime * 12f);
        PlayerCamera.fieldOfView = Mathf.Lerp(PlayerCamera.fieldOfView, aiming ? (Weapon.Current.Id == "awp" ? 30f : 55f) : 74f, Time.deltaTime * 10f);
    }

    private void UpdateWeapon(bool settingsOpen)
    {
        bool held = !settingsOpen && controls != null && controls.FireHeld;
        bool pressed = !settingsOpen && controls != null && controls.ConsumeFirePressed();
        if (!Application.isMobilePlatform && !settingsOpen)
        {
            bool desktopFire = Input.GetMouseButton(0);
            pressed |= desktopFire && !desktopFirePrevious;
            held |= desktopFire;
            desktopFirePrevious = desktopFire;
        }
        else if (Application.isMobilePlatform)
        {
            // Never read mouse button state on Android: Unity can synthesize it from
            // any screen touch. Only the explicit FIRE touch role reaches this point.
            desktopFirePrevious = false;
        }

        if ((Weapon.Current.Automatic && held) || (!Weapon.Current.Automatic && pressed))
        {
            float accuracy = (controls != null && controls.AdsHeld) ? 0.55f : 1f;
            Weapon.TryFire(PlayerCamera.transform.position, GetAimDirection(), accuracy);
        }

        bool reload = controls != null && controls.ConsumeReloadPressed();
        bool swap = controls != null && controls.ConsumeSwapPressed();
        if (!Application.isMobilePlatform)
        {
            reload |= Input.GetKeyDown(KeyCode.R);
            swap |= Input.GetKeyDown(KeyCode.Q);
        }
        if (reload) Weapon.StartReload();
        if (swap) NextWeapon();
    }

    private Vector3 GetAimDirection()
    {
        Vector3 direction = PlayerCamera.transform.forward;
        if (controls == null || !controls.AimAssist) return direction;
        CombatActor best = null;
        float bestAngle = 5.5f;
        foreach (CombatActor actor in game.Actors)
        {
            if (!actor.Alive || actor.Team == Actor.Team) continue;
            Vector3 toTarget = (actor.AimPoint.position - PlayerCamera.transform.position).normalized;
            float angle = Vector3.Angle(direction, toTarget);
            if (angle < bestAngle && game.HasLineOfSight(PlayerCamera.transform.position, actor, Actor))
            {
                bestAngle = angle;
                best = actor;
            }
        }
        if (best != null)
            direction = Vector3.Slerp(direction, (best.AimPoint.position - PlayerCamera.transform.position).normalized, 0.38f);
        return direction;
    }

    private void NextWeapon()
    {
        weaponIndex = (weaponIndex + 1) % WeaponCatalog.Active.Length;
        Weapon.Equip(WeaponCatalog.Active[weaponIndex].Id, true);
        if (game.Hud != null) game.Hud.ShowAnnouncement("EQUIPPED " + Weapon.Current.DisplayName, 1.1f);
    }

    private int FindWeaponIndex(string id)
    {
        for (int index = 0; index < WeaponCatalog.Active.Length; index++)
            if (WeaponCatalog.Active[index].Id == id) return index;
        return 0;
    }

    private void ApplyRecoil(float recoil)
    {
        pitch = Mathf.Clamp(pitch - recoil * 0.62f, -82f, 82f);
        yaw += Random.Range(-recoil, recoil) * 0.12f;
    }

    private void OnWeaponStatsChanged()
    {
        if (game != null && game.Hud != null) game.Hud.RefreshPlayerStats();
    }

    public void SetAlive(bool value)
    {
        alive = value;
        if (!value)
        {
            verticalVelocity = 0f;
            if (game != null && game.Hud != null) game.Hud.ShowAnnouncement("YOU ARE DOWN — REDEPLOYING", 2.8f);
        }
    }
}

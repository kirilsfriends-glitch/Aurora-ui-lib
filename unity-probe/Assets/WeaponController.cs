using System;
using UnityEngine;
using UnityEngine.Rendering;

[Serializable]
public sealed class WeaponDefinition
{
    public string Id;
    public string DisplayName;
    public float Damage;
    public float Rpm;
    public int Magazine;
    public int Reserve;
    public float ReloadTime;
    public float Spread;
    public float Recoil;
    public float Range;
    public bool Automatic;
    public float MoveMultiplier;
    public float PreferredRange;

    public WeaponDefinition(string id, string displayName, float damage, float rpm, int magazine, int reserve,
        float reloadTime, float spread, float recoil, float range, bool automatic, float moveMultiplier, float preferredRange)
    {
        Id = id; DisplayName = displayName; Damage = damage; Rpm = rpm; Magazine = magazine; Reserve = reserve;
        ReloadTime = reloadTime; Spread = spread; Recoil = recoil; Range = range; Automatic = automatic;
        MoveMultiplier = moveMultiplier; PreferredRange = preferredRange;
    }
}

public static class WeaponCatalog
{
    public static readonly WeaponDefinition[] Active =
    {
        new WeaponDefinition("ak47", "AK-47", 36f, 600f, 30, 90, 2.35f, 0.012f, 1.55f, 95f, true, 0.94f, 16f),
        new WeaponDefinition("m4a1", "M4A1", 31f, 720f, 30, 90, 2.15f, 0.009f, 1.15f, 95f, true, 0.96f, 17f),
        new WeaponDefinition("awp", "AWP", 118f, 48f, 10, 30, 3.1f, 0.001f, 4.8f, 180f, false, 0.72f, 28f),
        new WeaponDefinition("glock", "GLOCK-18", 24f, 420f, 20, 80, 1.65f, 0.018f, 0.8f, 55f, false, 1.02f, 10f)
    };

    public static WeaponDefinition Get(string id)
    {
        foreach (WeaponDefinition weapon in Active)
            if (weapon.Id == id) return weapon;
        return Active[0];
    }
}

public sealed class WeaponController : MonoBehaviour
{
    public WeaponDefinition Current { get; private set; }
    public int Ammo { get; private set; }
    public int Reserve { get; private set; }
    public bool Reloading { get { return reloadTimer > 0f; } }

    public event Action StatsChanged;
    public event Action<float> RecoilRequested;

    private CombatActor owner;
    private AuroraGame game;
    private AuroraMaterials materials;
    private Transform mount;
    private GameObject viewModel;
    private GameObject muzzleFlash;
    private AudioSource audioSource;
    private AudioClip rifleShot;
    private AudioClip sniperShot;
    private AudioClip pistolShot;
    private float nextShotTime;
    private float reloadTimer;
    private float muzzleTimer;
    private bool firstPerson;
    private Vector3 baseMountPosition;
    private Quaternion baseMountRotation;
    private float recoilKick;

    public void Initialize(AuroraGame gameManager, CombatActor actor, Transform weaponMount, string weaponId, bool isFirstPerson)
    {
        game = gameManager;
        owner = actor;
        materials = game.Materials;
        mount = weaponMount;
        firstPerson = isFirstPerson;
        baseMountPosition = mount.localPosition;
        baseMountRotation = mount.localRotation;
        audioSource = gameObject.AddComponent<AudioSource>();
        audioSource.spatialBlend = firstPerson ? 0f : 0.92f;
        audioSource.minDistance = 2.5f;
        audioSource.maxDistance = 42f;
        audioSource.volume = firstPerson ? 0.42f : 0.20f;
        rifleShot = SynthesizeShot("Rifle Shot", 0.105f, 150f, 0.72f);
        sniperShot = SynthesizeShot("Sniper Shot", 0.18f, 90f, 0.9f);
        pistolShot = SynthesizeShot("Pistol Shot", 0.075f, 210f, 0.52f);
        Equip(weaponId, true);
    }

    private void Update()
    {
        if (reloadTimer > 0f)
        {
            reloadTimer -= Time.deltaTime;
            if (reloadTimer <= 0f)
            {
                int transfer = Mathf.Min(Current.Magazine - Ammo, Reserve);
                Ammo += transfer;
                Reserve -= transfer;
                StatsChanged?.Invoke();
            }
        }
        if (muzzleTimer > 0f)
        {
            muzzleTimer -= Time.deltaTime;
            if (muzzleTimer <= 0f && muzzleFlash != null) muzzleFlash.SetActive(false);
        }
        recoilKick = Mathf.Lerp(recoilKick, 0f, Time.deltaTime * 13f);
        if (mount != null)
        {
            Vector3 posePosition = baseMountPosition + Vector3.back * recoilKick * 0.045f;
            Quaternion poseRotation = baseMountRotation * Quaternion.Euler(-recoilKick * 1.8f, 0f, recoilKick * 0.35f);
            if (Reloading)
            {
                float motion = Mathf.Sin(Time.time * 8f) * 4f;
                posePosition += new Vector3(-0.08f, -0.16f, -0.08f);
                poseRotation *= Quaternion.Euler(34f + motion, 0f, -24f);
            }
            mount.localPosition = Vector3.Lerp(mount.localPosition, posePosition, Time.deltaTime * 12f);
            mount.localRotation = Quaternion.Slerp(mount.localRotation, poseRotation, Time.deltaTime * 12f);
        }
    }

    public void Equip(string weaponId, bool refill)
    {
        Current = WeaponCatalog.Get(weaponId);
        reloadTimer = 0f;
        if (refill)
        {
            Ammo = Current.Magazine;
            Reserve = Current.Reserve;
        }
        BuildModel();
        StatsChanged?.Invoke();
    }

    public void Refill()
    {
        if (Current == null) return;
        Ammo = Current.Magazine;
        Reserve = Current.Reserve;
        reloadTimer = 0f;
        StatsChanged?.Invoke();
    }

    public bool TryFire(Vector3 origin, Vector3 forward, float accuracyMultiplier = 1f)
    {
        if (Current == null || owner == null || !owner.Alive || Reloading || Time.time < nextShotTime)
            return false;
        if (Ammo <= 0)
        {
            StartReload();
            return false;
        }

        Ammo--;
        nextShotTime = Time.time + 60f / Current.Rpm;
        Vector2 spread = UnityEngine.Random.insideUnitCircle * Current.Spread * accuracyMultiplier;
        Vector3 direction = (forward + transform.right * spread.x + Vector3.up * spread.y).normalized;
        RaycastHit hit;
        Vector3 end = origin + direction * Current.Range;
        if (Physics.Raycast(origin, direction, out hit, Current.Range, ~0, QueryTriggerInteraction.Ignore))
        {
            end = hit.point;
            CombatActor victim = hit.collider.GetComponentInParent<CombatActor>();
            if (victim != null)
                victim.TakeDamage(Current.Damage, owner, hit.point);
            else
                CreateImpact(hit.point, hit.normal);
        }

        CreateTracer(origin, end);
        PlayShotEffects();
        recoilKick = Mathf.Min(4.5f, recoilKick + Current.Recoil);
        if (firstPerson) RecoilRequested?.Invoke(Current.Recoil);
        StatsChanged?.Invoke();
        if (Ammo == 0) StartReload();
        return true;
    }

    public void StartReload()
    {
        if (Current == null || Reloading || Ammo >= Current.Magazine || Reserve <= 0)
            return;
        reloadTimer = Current.ReloadTime;
        StatsChanged?.Invoke();
    }

    private void BuildModel()
    {
        if (viewModel != null) Destroy(viewModel);
        if (muzzleFlash != null) Destroy(muzzleFlash);
        GameObject prefab = Resources.Load<GameObject>("Models/" + Current.Id);
        if (prefab != null)
        {
            viewModel = Instantiate(prefab, mount);
            viewModel.name = Current.DisplayName + (firstPerson ? " View Model" : " World Model");
            viewModel.transform.localPosition = Vector3.zero;
            viewModel.transform.localRotation = Quaternion.identity;
            float scale = firstPerson ? (Current.Id == "glock" ? 0.82f : 0.68f) : (Current.Id == "glock" ? 0.62f : 0.52f);
            viewModel.transform.localScale = Vector3.one * scale;
            materials.ApplyWeaponPalette(viewModel);
            foreach (Collider collider in viewModel.GetComponentsInChildren<Collider>()) Destroy(collider);
        }
        else
        {
            viewModel = BuildFallbackWeapon();
        }

        muzzleFlash = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        muzzleFlash.name = "Muzzle Flash";
        muzzleFlash.transform.SetParent(mount, false);
        float muzzleDistance;
        if (Current.Id == "glock") muzzleDistance = firstPerson ? 0.44f : 0.33f;
        else if (Current.Id == "awp") muzzleDistance = firstPerson ? 0.92f : 0.70f;
        else muzzleDistance = firstPerson ? 0.71f : 0.54f;
        muzzleFlash.transform.localPosition = new Vector3(0f, 0.06f, muzzleDistance);
        muzzleFlash.transform.localScale = Vector3.one * (Current.Id == "awp" ? 0.15f : 0.09f);
        muzzleFlash.GetComponent<Renderer>().sharedMaterial = materials.Safety;
        Destroy(muzzleFlash.GetComponent<Collider>());
        muzzleFlash.SetActive(false);
    }

    private GameObject BuildFallbackWeapon()
    {
        GameObject root = new GameObject(Current.DisplayName + " Procedural Model");
        root.transform.SetParent(mount, false);
        AuroraMaterials.CreateBox("Receiver", root.transform, new Vector3(0f, 0f, 0.2f), new Vector3(0.18f, 0.18f, 0.55f), materials.Gunmetal, false);
        AuroraMaterials.CreateCylinder("Barrel", root.transform, new Vector3(0f, 0.04f, 0.68f), new Vector3(0.035f, 0.28f, 0.035f), materials.Steel, false).transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
        AuroraMaterials.CreateBox("Grip", root.transform, new Vector3(0f, -0.18f, 0.05f), new Vector3(0.13f, 0.32f, 0.16f), materials.Polymer, false);
        return root;
    }

    private void PlayShotEffects()
    {
        if (muzzleFlash != null)
        {
            muzzleFlash.SetActive(true);
            muzzleFlash.transform.localScale = Vector3.one * UnityEngine.Random.Range(0.07f, 0.14f);
            muzzleTimer = 0.045f;
        }
        AudioClip clip = Current.Id == "awp" ? sniperShot : (Current.Id == "glock" ? pistolShot : rifleShot);
        if (audioSource != null && clip != null) audioSource.PlayOneShot(clip);
    }

    private void CreateTracer(Vector3 start, Vector3 end)
    {
        GameObject tracer = new GameObject("Bullet Tracer");
        LineRenderer line = tracer.AddComponent<LineRenderer>();
        line.sharedMaterial = materials.Cyan;
        line.positionCount = 2;
        line.SetPosition(0, start);
        line.SetPosition(1, end);
        line.startWidth = 0.022f;
        line.endWidth = 0.004f;
        line.shadowCastingMode = ShadowCastingMode.Off;
        line.receiveShadows = false;
        Destroy(tracer, 0.055f);
    }

    private void CreateImpact(Vector3 position, Vector3 normal)
    {
        GameObject impact = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        impact.name = "Impact Spark";
        impact.transform.position = position + normal * 0.015f;
        impact.transform.localScale = Vector3.one * 0.055f;
        impact.GetComponent<Renderer>().sharedMaterial = materials.Safety;
        Destroy(impact.GetComponent<Collider>());
        Destroy(impact, 0.16f);
    }

    private static AudioClip SynthesizeShot(string clipName, float duration, float bassFrequency, float volume)
    {
        const int sampleRate = 22050;
        int count = Mathf.CeilToInt(duration * sampleRate);
        float[] samples = new float[count];
        System.Random random = new System.Random(clipName.GetHashCode());
        for (int index = 0; index < count; index++)
        {
            float time = index / (float)sampleRate;
            float envelope = Mathf.Exp(-time * 28f);
            float noise = (float)(random.NextDouble() * 2.0 - 1.0);
            float bass = Mathf.Sin(time * bassFrequency * Mathf.PI * 2f);
            samples[index] = (noise * 0.62f + bass * 0.38f) * envelope * volume;
        }
        AudioClip clip = AudioClip.Create(clipName, count, 1, sampleRate, false);
        clip.SetData(samples, 0);
        return clip;
    }
}

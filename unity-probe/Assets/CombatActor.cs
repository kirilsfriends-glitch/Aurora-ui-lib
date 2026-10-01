using UnityEngine;

public sealed class CombatActor : MonoBehaviour
{
    public AuroraGame Game { get; private set; }
    public int Team { get; private set; }
    public int SpawnIndex { get; private set; }
    public string Callsign { get; private set; }
    public bool IsPlayer { get; private set; }
    public bool Alive { get; private set; }
    public float Health { get; private set; }
    public float Invulnerability { get; private set; }
    public Transform AimPoint { get; private set; }
    public GameObject VisualRoot { get; private set; }

    private CharacterController characterController;

    public void Initialize(AuroraGame game, int team, int spawnIndex, string callsign, bool isPlayer, GameObject visualRoot, Transform aimPoint)
    {
        Game = game;
        Team = team;
        SpawnIndex = spawnIndex;
        Callsign = callsign;
        IsPlayer = isPlayer;
        VisualRoot = visualRoot;
        AimPoint = aimPoint != null ? aimPoint : transform;
        characterController = GetComponent<CharacterController>();
        Respawn(game.Map.GetSpawn(team, spawnIndex));
    }

    private void Update()
    {
        Invulnerability = Mathf.Max(0f, Invulnerability - Time.deltaTime);
    }

    public void TakeDamage(float damage, CombatActor attacker, Vector3 hitPoint)
    {
        if (!Alive || attacker == this || (attacker != null && attacker.Team == Team) || Invulnerability > 0f)
            return;

        bool headshot = hitPoint.y > transform.position.y + 1.48f;
        float appliedDamage = headshot ? damage * 1.55f : damage;
        Health = Mathf.Max(0f, Health - appliedDamage);
        if (IsPlayer && Game.Hud != null)
            Game.Hud.ShowDamage(transform.InverseTransformPoint(attacker != null ? attacker.transform.position : hitPoint), Health);
        if (attacker != null && attacker.IsPlayer && Game.Hud != null)
            Game.Hud.ShowHitMarker(headshot);

        if (Health <= 0f)
            Die(attacker, headshot);
    }

    private void Die(CombatActor killer, bool headshot)
    {
        if (!Alive) return;
        Alive = false;
        if (characterController != null) characterController.enabled = false;
        if (VisualRoot != null) VisualRoot.SetActive(false);
        PlayerController player = GetComponent<PlayerController>();
        if (player != null) player.SetAlive(false);
        TacticalBot bot = GetComponent<TacticalBot>();
        if (bot != null) bot.SetAlive(false);
        Game.OnActorKilled(this, killer, headshot);
    }

    public void Respawn(Vector3 position)
    {
        if (characterController == null) characterController = GetComponent<CharacterController>();
        if (characterController != null) characterController.enabled = false;
        transform.position = position;
        transform.rotation = Quaternion.Euler(0f, Team == 0 ? 90f : -90f, 0f);
        Health = 100f;
        Alive = true;
        Invulnerability = 1.4f;
        if (VisualRoot != null) VisualRoot.SetActive(true);
        if (characterController != null) characterController.enabled = true;
        PlayerController player = GetComponent<PlayerController>();
        if (player != null) player.SetAlive(true);
        TacticalBot bot = GetComponent<TacticalBot>();
        if (bot != null) bot.SetAlive(true);
        WeaponController weapon = GetComponent<WeaponController>();
        if (weapon != null) weapon.Refill();
    }
}

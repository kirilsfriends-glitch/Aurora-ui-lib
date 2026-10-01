using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public sealed class AuroraGame : MonoBehaviour
{
    public AuroraMaterials Materials { get; private set; }
    public DockyardMap Map { get; private set; }
    public PlayerController Player { get; private set; }
    public AuroraHud Hud { get; private set; }
    public List<CombatActor> Actors { get; private set; } = new List<CombatActor>();
    public int AlphaScore { get; private set; }
    public int BravoScore { get; private set; }
    public float RemainingTime { get; private set; }
    public bool MatchActive { get; private set; }

    private const int ScoreLimit = 30;
    private const float MatchLength = 420f;
    private bool endingRound;

    public void Initialize(Shader mobileLitShader)
    {
        name = "Aurora Strike Game";
        Materials = new AuroraMaterials(mobileLitShader);

        GameObject mapObject = new GameObject("Dockyard Map");
        mapObject.transform.SetParent(transform, false);
        Map = mapObject.AddComponent<DockyardMap>();
        Map.Build(Materials);

        SpawnPlayer();
        SpawnBots();

        Hud = gameObject.AddComponent<AuroraHud>();
        Hud.Build(this);
        MobileControls controls = gameObject.AddComponent<MobileControls>();
        controls.Build(Hud.Canvas);
        Player.SetControls(controls);

        AlphaScore = 0;
        BravoScore = 0;
        RemainingTime = MatchLength;
        MatchActive = true;
        Hud.ShowAnnouncement("AURORA STRIKE\nTEAM DEATHMATCH  •  5v5", 3.2f);
    }

    private void Update()
    {
        if (!MatchActive || endingRound) return;
        RemainingTime = Mathf.Max(0f, RemainingTime - Time.deltaTime);
        if (RemainingTime <= 0f || AlphaScore >= ScoreLimit || BravoScore >= ScoreLimit)
            StartCoroutine(FinishRound());
    }

    private void SpawnPlayer()
    {
        GameObject playerObject = new GameObject("Local Player");
        playerObject.transform.SetParent(transform, false);
        Player = playerObject.AddComponent<PlayerController>();
        Player.Initialize(this, 0, "ak47");
        Actors.Add(Player.Actor);
    }

    private void SpawnBots()
    {
        string[] alphaWeapons = { "m4a1", "ak47", "glock", "awp" };
        string[] bravoWeapons = { "m4a1", "ak47", "glock", "m4a1", "awp" };
        for (int index = 1; index < 5; index++)
            SpawnBot(0, index, alphaWeapons[index - 1], 0.64f + index * 0.045f);
        for (int index = 0; index < 5; index++)
            SpawnBot(1, index, bravoWeapons[index], 0.62f + index * 0.05f);
    }

    private void SpawnBot(int team, int index, string weapon, float skill)
    {
        GameObject botObject = new GameObject("Bot");
        botObject.transform.SetParent(transform, false);
        TacticalBot bot = botObject.AddComponent<TacticalBot>();
        bot.Initialize(this, team, index, weapon, skill);
        Actors.Add(bot.Actor);
    }

    public void OnActorKilled(CombatActor victim, CombatActor killer, bool headshot)
    {
        if (!MatchActive) return;
        if (killer != null && killer.Team != victim.Team)
        {
            if (killer.Team == 0) AlphaScore++;
            else BravoScore++;
        }
        if (Hud != null) Hud.ShowKill(victim, killer, headshot);
        StartCoroutine(RespawnActor(victim));
    }

    private IEnumerator RespawnActor(CombatActor actor)
    {
        yield return new WaitForSeconds(3.1f);
        if (MatchActive && actor != null)
            actor.Respawn(Map.GetSpawn(actor.Team, actor.SpawnIndex));
    }

    private IEnumerator FinishRound()
    {
        if (endingRound) yield break;
        endingRound = true;
        MatchActive = false;
        string result = AlphaScore == BravoScore ? "DRAW" : AlphaScore > BravoScore ? "ALPHA WINS" : "BRAVO WINS";
        if (Hud != null) Hud.ShowAnnouncement(result + "\nNEW ROUND IN 5", 5f);
        yield return new WaitForSeconds(5f);
        AlphaScore = 0;
        BravoScore = 0;
        RemainingTime = MatchLength;
        for (int index = 0; index < Actors.Count; index++)
            Actors[index].Respawn(Map.GetSpawn(Actors[index].Team, Actors[index].SpawnIndex));
        MatchActive = true;
        endingRound = false;
        Hud.ShowAnnouncement("ROUND START", 1.8f);
    }

    public bool HasLineOfSight(Vector3 origin, CombatActor target, CombatActor observer)
    {
        if (target == null || !target.Alive) return false;
        Vector3 direction = target.AimPoint.position - origin;
        RaycastHit hit;
        if (!Physics.Raycast(origin, direction.normalized, out hit, direction.magnitude + 0.25f, ~0, QueryTriggerInteraction.Ignore))
            return true;
        CombatActor hitActor = hit.collider.GetComponentInParent<CombatActor>();
        return hitActor == target || (hitActor == observer && Physics.Raycast(hit.point + direction.normalized * 0.08f, direction.normalized, out hit, direction.magnitude, ~0, QueryTriggerInteraction.Ignore) && hit.collider.GetComponentInParent<CombatActor>() == target);
    }
}

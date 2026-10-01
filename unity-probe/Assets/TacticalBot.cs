using System;
using System.Collections.Generic;
using UnityEngine;

public sealed class TacticalBot : MonoBehaviour
{
    private enum BotState { Patrol, Hunt, Combat, Cover }

    public CombatActor Actor { get; private set; }
    public WeaponController Weapon { get; private set; }

    private AuroraGame game;
    private CharacterController controller;
    private OperatorRig rig;
    private CombatActor target;
    private BotState state;
    private List<Vector3> path = new List<Vector3>();
    private int pathIndex;
    private Vector3 moveGoal;
    private float thinkTimer;
    private float reactionTimer;
    private float patrolTimer;
    private float gravity;
    private float strafeSign = 1f;
    private float skill;
    private bool alive = true;
    private System.Random random;

    public void Initialize(AuroraGame gameManager, int team, int botIndex, string weaponId, float botSkill)
    {
        game = gameManager;
        skill = Mathf.Clamp(botSkill, 0.35f, 0.96f);
        random = new System.Random(1739 + botIndex * 7919 + team * 103);
        gameObject.name = (team == 0 ? "Alpha" : "Bravo") + " Bot " + (botIndex + 1);

        controller = gameObject.AddComponent<CharacterController>();
        controller.radius = 0.36f;
        controller.height = 1.78f;
        controller.center = new Vector3(0f, 0.89f, 0f);
        controller.stepOffset = 0.34f;
        controller.slopeLimit = 46f;
        controller.skinWidth = 0.045f;

        GameObject visual = new GameObject("Operator Visual");
        visual.transform.SetParent(transform, false);
        rig = visual.AddComponent<OperatorRig>();
        rig.Build(game.Materials, team);

        Actor = gameObject.AddComponent<CombatActor>();
        Weapon = gameObject.AddComponent<WeaponController>();
        Actor.Initialize(game, team, botIndex, (team == 0 ? "ALPHA-" : "BRAVO-") + (botIndex + 1), false, visual, rig.AimPoint);
        Weapon.Initialize(game, Actor, rig.WeaponMount, weaponId, false);
        moveGoal = transform.position;
        patrolTimer = 0.2f;
    }

    private void Update()
    {
        if (!alive || Actor == null || !Actor.Alive || game == null || !game.MatchActive)
            return;

        thinkTimer -= Time.deltaTime;
        reactionTimer = Mathf.Max(0f, reactionTimer - Time.deltaTime);
        patrolTimer -= Time.deltaTime;
        if (thinkTimer <= 0f)
        {
            thinkTimer = Mathf.Lerp(0.42f, 0.14f, skill) + NextFloat(-0.03f, 0.03f);
            Think();
        }

        Vector3 movement = MoveBot();
        Fight();
        rig.Animate(transform.InverseTransformDirection(movement), state == BotState.Combat, Time.deltaTime);
    }

    private void Think()
    {
        CombatActor visible = FindVisibleEnemy();
        if (visible != null)
        {
            if (target != visible)
                reactionTimer = Mathf.Lerp(0.78f, 0.18f, skill) + NextFloat(0f, 0.15f);
            target = visible;
            if (Actor.Health < 28f || Weapon.Reloading)
            {
                state = BotState.Cover;
                SetGoal(game.Map.GetCoverFrom(transform.position, target.transform.position, random));
            }
            else
            {
                state = BotState.Combat;
            }
        }
        else if (target != null && target.Alive)
        {
            state = BotState.Hunt;
            SetGoal(target.transform.position);
            target = null;
        }
        else if (patrolTimer <= 0f || Vector3.Distance(transform.position, moveGoal) < 1.4f)
        {
            target = null;
            state = BotState.Patrol;
            patrolTimer = NextFloat(3f, 6f);
            SetGoal(game.Map.GetRandomWaypoint(random));
        }

        if (Weapon.Ammo <= 0 && !Weapon.Reloading)
        {
            Weapon.StartReload();
            if (target != null) SetGoal(game.Map.GetCoverFrom(transform.position, target.transform.position, random));
        }
    }

    private CombatActor FindVisibleEnemy()
    {
        CombatActor best = null;
        float bestScore = float.MaxValue;
        foreach (CombatActor candidate in game.Actors)
        {
            if (candidate == Actor || !candidate.Alive || candidate.Team == Actor.Team) continue;
            Vector3 offset = candidate.AimPoint.position - rig.AimPoint.position;
            float distance = offset.magnitude;
            if (distance > 48f) continue;
            float angle = Vector3.Angle(transform.forward, offset);
            if (angle > (target == null ? 78f : 112f)) continue;
            if (!game.HasLineOfSight(rig.AimPoint.position, candidate, Actor)) continue;
            float score = distance + angle * 0.08f + NextFloat(0f, 1.2f);
            if (score < bestScore)
            {
                bestScore = score;
                best = candidate;
            }
        }
        return best;
    }

    private void SetGoal(Vector3 destination)
    {
        if (Vector3.Distance(moveGoal, destination) < 1.6f && path.Count > 0) return;
        moveGoal = destination;
        path = game.Map.FindPath(transform.position, destination);
        pathIndex = 0;
    }

    private Vector3 MoveBot()
    {
        Vector3 desired = Vector3.zero;
        if (state == BotState.Combat && target != null && target.Alive)
        {
            Vector3 toTarget = target.transform.position - transform.position;
            toTarget.y = 0f;
            float distance = toTarget.magnitude;
            if (distance > Weapon.Current.PreferredRange * 1.2f) desired += toTarget.normalized;
            else if (distance < Weapon.Current.PreferredRange * 0.55f) desired -= toTarget.normalized;
            desired += Vector3.Cross(Vector3.up, toTarget.normalized) * strafeSign * 0.68f;
            if (random.NextDouble() < 0.008) strafeSign *= -1f;
        }
        else if (pathIndex < path.Count)
        {
            Vector3 offset = path[pathIndex] - transform.position;
            offset.y = 0f;
            if (offset.magnitude < 1.0f) pathIndex++;
            else desired = offset.normalized;
        }
        else
        {
            Vector3 offset = moveGoal - transform.position;
            offset.y = 0f;
            if (offset.magnitude > 0.8f) desired = offset.normalized;
        }

        foreach (CombatActor ally in game.Actors)
        {
            if (ally == Actor || !ally.Alive || ally.Team != Actor.Team) continue;
            Vector3 away = transform.position - ally.transform.position;
            away.y = 0f;
            if (away.sqrMagnitude > 0.01f && away.sqrMagnitude < 2.1f)
                desired += away.normalized * 0.72f;
        }
        desired = Vector3.ClampMagnitude(desired, 1f);
        float speed = 5.35f * Weapon.Current.MoveMultiplier * (state == BotState.Combat ? 0.82f : 1f);
        if (controller.isGrounded) gravity = -1.2f;
        else gravity -= 21f * Time.deltaTime;
        Vector3 velocity = desired * speed;
        velocity.y = gravity;
        controller.Move(velocity * Time.deltaTime);

        Vector3 face = desired;
        if (state == BotState.Combat && target != null && target.Alive)
        {
            face = target.AimPoint.position - rig.AimPoint.position;
            face.y = 0f;
        }
        if (face.sqrMagnitude > 0.02f)
            transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(face.normalized, Vector3.up), Time.deltaTime * 8.5f);
        return velocity;
    }

    private void Fight()
    {
        if (state != BotState.Combat || target == null || !target.Alive || reactionTimer > 0f || Weapon.Reloading)
            return;
        Vector3 origin = rig.AimPoint.position + transform.forward * 0.24f;
        if (!game.HasLineOfSight(origin, target, Actor)) return;
        Vector3 targetPoint = target.AimPoint.position;
        if (random.NextDouble() < skill * 0.25) targetPoint += Vector3.up * 0.28f;
        Vector3 direction = (targetPoint - origin).normalized;
        if (FriendlyBlocks(origin, direction, Vector3.Distance(origin, targetPoint) + 1f)) return;
        float inaccuracy = Mathf.Lerp(4.8f, 1.35f, skill);
        Weapon.TryFire(origin, direction, inaccuracy);
    }

    private bool FriendlyBlocks(Vector3 origin, Vector3 direction, float distance)
    {
        RaycastHit hit;
        if (!Physics.Raycast(origin, direction, out hit, distance, ~0, QueryTriggerInteraction.Ignore)) return false;
        CombatActor actor = hit.collider.GetComponentInParent<CombatActor>();
        return actor != null && actor != Actor && actor.Team == Actor.Team;
    }

    public void SetAlive(bool value)
    {
        alive = value;
        target = null;
        path.Clear();
        pathIndex = 0;
        gravity = 0f;
        thinkTimer = 0f;
        patrolTimer = 0f;
    }

    private float NextFloat(float minimum, float maximum)
    {
        return Mathf.Lerp(minimum, maximum, (float)random.NextDouble());
    }
}

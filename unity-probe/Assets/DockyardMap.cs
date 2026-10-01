using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public sealed class DockyardMap : MonoBehaviour
{
    private struct Obstacle
    {
        public Vector3 center;
        public Vector3 size;
        public Obstacle(Vector3 center, Vector3 size) { this.center = center; this.size = size; }
    }

    private readonly List<Obstacle> obstacles = new List<Obstacle>();
    private readonly List<Vector3> coverPoints = new List<Vector3>();
    private AuroraMaterials materials;
    private const float GridStep = 2.4f;
    private const int GridWidth = 29;
    private const int GridHeight = 18;
    private const float MinX = -33.6f;
    private const float MinZ = -20.4f;

    public readonly Vector3[] AlphaSpawns =
    {
        new Vector3(-31f, 0.05f, -5.5f), new Vector3(-30f, 0.05f, -2.8f),
        new Vector3(-31f, 0.05f, 0f), new Vector3(-30f, 0.05f, 2.8f),
        new Vector3(-31f, 0.05f, 5.5f)
    };

    public readonly Vector3[] BravoSpawns =
    {
        new Vector3(31f, 0.05f, 5.5f), new Vector3(30f, 0.05f, 2.8f),
        new Vector3(31f, 0.05f, 0f), new Vector3(30f, 0.05f, -2.8f),
        new Vector3(31f, 0.05f, -5.5f)
    };

    public IReadOnlyList<Vector3> CoverPoints { get { return coverPoints; } }

    public void Build(AuroraMaterials materialLibrary)
    {
        materials = materialLibrary;
        name = "Dockyard_Daylight";
        BuildLighting();
        BuildDeckAndWarehouses();
        BuildTacticalLayout();
        BuildLandmarks();
    }

    private void BuildLighting()
    {
        RenderSettings.ambientMode = AmbientMode.Flat;
        RenderSettings.ambientLight = new Color(0.54f, 0.61f, 0.67f);
        RenderSettings.fog = true;
        RenderSettings.fogMode = FogMode.Linear;
        RenderSettings.fogColor = new Color(0.57f, 0.72f, 0.82f);
        RenderSettings.fogStartDistance = 52f;
        RenderSettings.fogEndDistance = 115f;

        GameObject sunObject = new GameObject("Morning Sun");
        sunObject.transform.SetParent(transform, false);
        sunObject.transform.rotation = Quaternion.Euler(48f, -32f, 0f);
        Light sun = sunObject.AddComponent<Light>();
        sun.type = LightType.Directional;
        sun.color = new Color(1f, 0.92f, 0.78f);
        sun.intensity = 1.18f;
        sun.shadows = LightShadows.Hard;
        sun.shadowStrength = 0.55f;
        sun.shadowBias = 0.06f;

        GameObject fillObject = new GameObject("Sky Fill");
        fillObject.transform.SetParent(transform, false);
        fillObject.transform.rotation = Quaternion.Euler(32f, 148f, 0f);
        Light fill = fillObject.AddComponent<Light>();
        fill.type = LightType.Directional;
        fill.color = new Color(0.56f, 0.78f, 1f);
        fill.intensity = 0.36f;
        fill.shadows = LightShadows.None;
    }

    private void BuildDeckAndWarehouses()
    {
        CreateObstacle("Dock Deck", new Vector3(0f, -0.3f, 0f), new Vector3(72f, 0.6f, 46f), materials.Deck, false);
        CreateObstacle("North Warehouse", new Vector3(0f, 3.6f, -22.4f), new Vector3(72f, 7.2f, 1.2f), materials.WarehouseBlue, false);
        CreateObstacle("South Warehouse", new Vector3(0f, 3.6f, 22.4f), new Vector3(72f, 7.2f, 1.2f), materials.WarehouseWarm, false);
        CreateObstacle("West Barrier", new Vector3(-35.6f, 2f, 0f), new Vector3(0.8f, 4f, 46f), materials.Steel, false);
        CreateObstacle("East Barrier", new Vector3(35.6f, 2f, 0f), new Vector3(0.8f, 4f, 46f), materials.Steel, false);

        for (int x = -30; x <= 30; x += 6)
        {
            AuroraMaterials.CreateBox("Lane Marker", transform, new Vector3(x, 0.014f, -9.3f), new Vector3(3.4f, 0.028f, 0.12f), materials.Safety, false);
            AuroraMaterials.CreateBox("Lane Marker", transform, new Vector3(x, 0.014f, 9.3f), new Vector3(3.4f, 0.028f, 0.12f), materials.Safety, false);
        }

        for (int x = -27; x <= 27; x += 9)
        {
            AuroraMaterials.CreateBox("Warehouse Bay North", transform, new Vector3(x, 2.35f, -21.75f), new Vector3(6.4f, 4.5f, 0.12f), materials.DarkMetal, false);
            AuroraMaterials.CreateBox("Warehouse Bay South", transform, new Vector3(x, 2.35f, 21.75f), new Vector3(6.4f, 4.5f, 0.12f), materials.DarkMetal, false);
            AuroraMaterials.CreateBox("North Bay Light", transform, new Vector3(x, 5.0f, -21.65f), new Vector3(6.7f, 0.14f, 0.14f), materials.Cyan, false);
            AuroraMaterials.CreateBox("South Bay Light", transform, new Vector3(x, 5.0f, 21.65f), new Vector3(6.7f, 0.14f, 0.14f), materials.Safety, false);
        }
    }

    private void BuildTacticalLayout()
    {
        AddContainer(new Vector3(-25f, 1.35f, -14f), new Vector3(8f, 2.7f, 2.8f), materials.ContainerBlue);
        AddContainer(new Vector3(-14f, 1.35f, -14f), new Vector3(10f, 2.7f, 2.8f), materials.ContainerOrange);
        AddContainer(new Vector3(2f, 1.35f, -14f), new Vector3(8f, 2.7f, 2.8f), materials.ContainerGreen);
        AddContainer(new Vector3(17f, 1.35f, -14f), new Vector3(12f, 2.7f, 2.8f), materials.ContainerBlue);
        AddContainer(new Vector3(28f, 1.35f, -8f), new Vector3(2.8f, 2.7f, 8f), materials.ContainerOrange);

        AddContainer(new Vector3(25f, 1.35f, 14f), new Vector3(8f, 2.7f, 2.8f), materials.ContainerOrange);
        AddContainer(new Vector3(14f, 1.35f, 14f), new Vector3(10f, 2.7f, 2.8f), materials.ContainerGreen);
        AddContainer(new Vector3(-2f, 1.35f, 14f), new Vector3(8f, 2.7f, 2.8f), materials.ContainerBlue);
        AddContainer(new Vector3(-17f, 1.35f, 14f), new Vector3(12f, 2.7f, 2.8f), materials.ContainerOrange);
        AddContainer(new Vector3(-28f, 1.35f, 8f), new Vector3(2.8f, 2.7f, 8f), materials.ContainerGreen);

        AddCustomsBuilding();
        AddCover(new Vector3(-25f, 0.58f, -3f), new Vector3(3.2f, 1.16f, 0.9f));
        AddCover(new Vector3(-17f, 0.63f, 4f), new Vector3(2.3f, 1.26f, 1.2f));
        AddCover(new Vector3(-10f, 0.63f, -6f), new Vector3(2.3f, 1.26f, 1.2f));
        AddCover(new Vector3(-9f, 0.58f, 8f), new Vector3(3.2f, 1.16f, 0.9f));
        AddCover(new Vector3(9f, 0.63f, -8f), new Vector3(2.3f, 1.26f, 1.2f));
        AddCover(new Vector3(10f, 0.63f, 6f), new Vector3(2.3f, 1.26f, 1.2f));
        AddCover(new Vector3(17f, 0.58f, -4f), new Vector3(3.2f, 1.16f, 0.9f));
        AddCover(new Vector3(25f, 0.63f, 3f), new Vector3(2.3f, 1.26f, 1.2f));
        AddCover(new Vector3(-4.8f, 0.63f, -8f), new Vector3(2.3f, 1.26f, 1.2f));
        AddCover(new Vector3(4.8f, 0.58f, 8f), new Vector3(3.2f, 1.16f, 0.9f));
    }

    private void AddContainer(Vector3 center, Vector3 size, Material material)
    {
        CreateObstacle("Cargo Container", center, size, material, true);
        bool longX = size.x > size.z;
        float length = longX ? size.x : size.z;
        int ribCount = Mathf.Max(2, Mathf.RoundToInt(length / 1.2f));
        for (int index = 0; index <= ribCount; index++)
        {
            float offset = Mathf.Lerp(-length * 0.47f, length * 0.47f, index / (float)ribCount);
            Vector3 ribPosition = center + (longX ? new Vector3(offset, 0f, -size.z * 0.505f) : new Vector3(-size.x * 0.505f, 0f, offset));
            Vector3 ribSize = longX ? new Vector3(0.07f, size.y * 0.9f, 0.07f) : new Vector3(0.07f, size.y * 0.9f, 0.07f);
            AuroraMaterials.CreateBox("Container Rib", transform, ribPosition, ribSize, materials.Steel, false);
        }
        AuroraMaterials.CreateBox("Container Stripe", transform,
            center + new Vector3(0f, size.y * 0.28f, longX ? -size.z * 0.508f : 0f),
            longX ? new Vector3(size.x * 0.58f, 0.12f, 0.04f) : new Vector3(0.04f, 0.12f, size.z * 0.58f),
            materials.Safety, false);
    }

    private void AddCustomsBuilding()
    {
        Vector3 center = new Vector3(0f, 2.05f, 0f);
        Vector3 size = new Vector3(13.5f, 4.1f, 8f);
        CreateObstacle("Customs Building", center, size, materials.WarehouseBlue, true);
        AuroraMaterials.CreateBox("Customs Roof", transform, new Vector3(0f, 4.2f, 0f), new Vector3(14.2f, 0.22f, 8.7f), materials.Steel, false);
        for (int x = -5; x <= 5; x += 2)
        {
            AuroraMaterials.CreateBox("Customs Window", transform, new Vector3(x, 2.65f, -4.03f), new Vector3(1.3f, 0.8f, 0.06f), materials.Glass, false);
            AuroraMaterials.CreateBox("Customs Window", transform, new Vector3(x, 2.65f, 4.03f), new Vector3(1.3f, 0.8f, 0.06f), materials.Glass, false);
        }
        AuroraMaterials.CreateBox("Customs Sign", transform, new Vector3(0f, 3.7f, -4.08f), new Vector3(5.8f, 0.35f, 0.08f), materials.Cyan, false);
    }

    private void AddCover(Vector3 center, Vector3 size)
    {
        CreateObstacle("Ballistic Cover", center, size, materials.Concrete, true);
        AuroraMaterials.CreateBox("Cover Accent", transform, center + new Vector3(0f, size.y * 0.3f, -size.z * 0.51f),
            new Vector3(size.x * 0.72f, 0.09f, 0.035f), materials.Safety, false);
    }

    private void BuildLandmarks()
    {
        for (int side = -1; side <= 1; side += 2)
        {
            float x = side * 24f;
            AuroraMaterials.CreateBox("Crane Column", transform, new Vector3(x, 4.5f, 18f), new Vector3(0.8f, 9f, 0.8f), materials.Safety, false);
            AuroraMaterials.CreateBox("Crane Boom", transform, new Vector3(x - side * 3.5f, 8.6f, 18f), new Vector3(7.8f, 0.55f, 0.55f), materials.Steel, false);
            AuroraMaterials.CreateBox("Team Beacon", transform, new Vector3(side * 31f, 3.1f, 0f), new Vector3(0.24f, 6.2f, 0.24f), side < 0 ? materials.Cyan : materials.Red, false);
        }
    }

    private GameObject CreateObstacle(string objectName, Vector3 center, Vector3 size, Material material, bool tactical)
    {
        GameObject result = AuroraMaterials.CreateBox(objectName, transform, center, size, material, true);
        Renderer renderer = result.GetComponent<Renderer>();
        renderer.shadowCastingMode = tactical ? ShadowCastingMode.On : ShadowCastingMode.Off;
        renderer.receiveShadows = true;
        if (tactical)
        {
            obstacles.Add(new Obstacle(center, size));
            AddCoverPoints(center, size);
        }
        return result;
    }

    private void AddCoverPoints(Vector3 center, Vector3 size)
    {
        coverPoints.Add(new Vector3(center.x + size.x * 0.5f + 0.85f, 0.05f, center.z));
        coverPoints.Add(new Vector3(center.x - size.x * 0.5f - 0.85f, 0.05f, center.z));
        coverPoints.Add(new Vector3(center.x, 0.05f, center.z + size.z * 0.5f + 0.85f));
        coverPoints.Add(new Vector3(center.x, 0.05f, center.z - size.z * 0.5f - 0.85f));
    }

    public Vector3 GetSpawn(int team, int index)
    {
        Vector3[] spawns = team == 0 ? AlphaSpawns : BravoSpawns;
        return spawns[Mathf.Abs(index) % spawns.Length];
    }

    public Vector3 GetRandomWaypoint(System.Random random)
    {
        for (int attempt = 0; attempt < 30; attempt++)
        {
            Vector3 candidate = new Vector3(
                Mathf.Lerp(-30f, 30f, (float)random.NextDouble()),
                0.05f,
                Mathf.Lerp(-18f, 18f, (float)random.NextDouble()));
            if (!IsBlocked(candidate, 0.7f))
                return candidate;
        }
        return Vector3.zero;
    }

    public Vector3 GetCoverFrom(Vector3 origin, Vector3 danger, System.Random random)
    {
        Vector3 best = origin;
        float bestScore = float.MaxValue;
        foreach (Vector3 point in coverPoints)
        {
            float distance = Vector3.Distance(origin, point);
            if (distance > 19f || IsBlocked(point, 0.45f))
                continue;
            Vector3 direction = danger - point;
            RaycastHit hit;
            bool protectedPoint = Physics.Raycast(point + Vector3.up, direction.normalized, out hit, direction.magnitude - 0.5f, ~0, QueryTriggerInteraction.Ignore);
            if (!protectedPoint)
                continue;
            float score = distance + (float)random.NextDouble() * 2.5f;
            if (score < bestScore)
            {
                bestScore = score;
                best = point;
            }
        }
        return best;
    }

    public List<Vector3> FindPath(Vector3 start, Vector3 destination)
    {
        Vector2Int startNode = ClosestOpenNode(ToNode(start));
        Vector2Int goalNode = ClosestOpenNode(ToNode(destination));
        List<Vector2Int> open = new List<Vector2Int> { startNode };
        HashSet<Vector2Int> closed = new HashSet<Vector2Int>();
        Dictionary<Vector2Int, Vector2Int> cameFrom = new Dictionary<Vector2Int, Vector2Int>();
        Dictionary<Vector2Int, float> cost = new Dictionary<Vector2Int, float> { { startNode, 0f } };

        Vector2Int[] directions =
        {
            new Vector2Int(1, 0), new Vector2Int(-1, 0), new Vector2Int(0, 1), new Vector2Int(0, -1),
            new Vector2Int(1, 1), new Vector2Int(1, -1), new Vector2Int(-1, 1), new Vector2Int(-1, -1)
        };

        while (open.Count > 0)
        {
            int bestIndex = 0;
            float bestEstimate = float.MaxValue;
            for (int index = 0; index < open.Count; index++)
            {
                Vector2Int node = open[index];
                float estimate = cost[node] + Vector2Int.Distance(node, goalNode);
                if (estimate < bestEstimate) { bestEstimate = estimate; bestIndex = index; }
            }
            Vector2Int current = open[bestIndex];
            open.RemoveAt(bestIndex);
            if (current == goalNode)
                return ReconstructPath(cameFrom, current, destination);
            closed.Add(current);

            foreach (Vector2Int offset in directions)
            {
                Vector2Int next = current + offset;
                if (!InGrid(next) || closed.Contains(next) || IsBlocked(ToWorld(next), 0.68f))
                    continue;
                float nextCost = cost[current] + (offset.x != 0 && offset.y != 0 ? 1.414f : 1f);
                float previous;
                if (!cost.TryGetValue(next, out previous) || nextCost < previous)
                {
                    cost[next] = nextCost;
                    cameFrom[next] = current;
                    if (!open.Contains(next)) open.Add(next);
                }
            }
        }
        return new List<Vector3> { destination };
    }

    private List<Vector3> ReconstructPath(Dictionary<Vector2Int, Vector2Int> cameFrom, Vector2Int current, Vector3 destination)
    {
        List<Vector3> result = new List<Vector3> { destination };
        while (cameFrom.ContainsKey(current))
        {
            result.Add(ToWorld(current));
            current = cameFrom[current];
        }
        result.Reverse();
        return result;
    }

    private Vector2Int ClosestOpenNode(Vector2Int desired)
    {
        desired.x = Mathf.Clamp(desired.x, 0, GridWidth - 1);
        desired.y = Mathf.Clamp(desired.y, 0, GridHeight - 1);
        if (!IsBlocked(ToWorld(desired), 0.68f)) return desired;
        for (int radius = 1; radius < 6; radius++)
        {
            for (int x = -radius; x <= radius; x++)
            for (int y = -radius; y <= radius; y++)
            {
                Vector2Int candidate = desired + new Vector2Int(x, y);
                if (InGrid(candidate) && !IsBlocked(ToWorld(candidate), 0.68f)) return candidate;
            }
        }
        return desired;
    }

    private Vector2Int ToNode(Vector3 position)
    {
        return new Vector2Int(Mathf.RoundToInt((position.x - MinX) / GridStep), Mathf.RoundToInt((position.z - MinZ) / GridStep));
    }

    private Vector3 ToWorld(Vector2Int node)
    {
        return new Vector3(MinX + node.x * GridStep, 0.05f, MinZ + node.y * GridStep);
    }

    private bool InGrid(Vector2Int node)
    {
        return node.x >= 0 && node.y >= 0 && node.x < GridWidth && node.y < GridHeight;
    }

    private bool IsBlocked(Vector3 point, float margin)
    {
        if (point.x < -34.4f || point.x > 34.4f || point.z < -21.2f || point.z > 21.2f)
            return true;
        foreach (Obstacle obstacle in obstacles)
        {
            if (Mathf.Abs(point.x - obstacle.center.x) < obstacle.size.x * 0.5f + margin &&
                Mathf.Abs(point.z - obstacle.center.z) < obstacle.size.z * 0.5f + margin)
                return true;
        }
        return false;
    }
}

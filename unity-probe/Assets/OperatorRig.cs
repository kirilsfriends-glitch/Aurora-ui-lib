using UnityEngine;

public sealed class OperatorRig : MonoBehaviour
{
    public Transform AimPoint { get; private set; }
    public Transform WeaponMount { get; private set; }

    private Transform visualBody;
    private Transform leftLeg;
    private Transform rightLeg;
    private Transform leftArm;
    private Transform rightArm;
    private Transform head;
    private float strideTime;

    public void Build(AuroraMaterials materials, int team)
    {
        gameObject.name = team == 0 ? "Alpha Operator Rig" : "Bravo Operator Rig";
        Material teamMaterial = team == 0 ? materials.BlueTeam : materials.RedTeam;

        visualBody = new GameObject("Animated Body").transform;
        visualBody.SetParent(transform, false);

        AuroraMaterials.CreateBox("Pelvis", visualBody, new Vector3(0f, 0.94f, 0f), new Vector3(0.42f, 0.25f, 0.28f), materials.Fabric, false);
        AuroraMaterials.CreateBox("Armored Torso", visualBody, new Vector3(0f, 1.31f, 0f), new Vector3(0.55f, 0.55f, 0.32f), materials.Armor, false);
        AuroraMaterials.CreateBox("Plate Carrier", visualBody, new Vector3(0f, 1.32f, 0.185f), new Vector3(0.47f, 0.42f, 0.10f), materials.Polymer, false);
        AuroraMaterials.CreateBox("Team Patch", visualBody, new Vector3(0f, 1.48f, 0.242f), new Vector3(0.25f, 0.075f, 0.02f), teamMaterial, false);
        for (int index = -1; index <= 1; index++)
            AuroraMaterials.CreateBox("Magazine Pouch", visualBody, new Vector3(index * 0.14f, 1.18f, 0.25f), new Vector3(0.11f, 0.22f, 0.075f), materials.Wood, false);

        leftLeg = BuildLeg("Left Leg", -0.15f, materials);
        rightLeg = BuildLeg("Right Leg", 0.15f, materials);
        leftArm = BuildArm("Left Arm", -0.36f, materials);
        rightArm = BuildArm("Right Arm", 0.36f, materials);

        AuroraMaterials.CreateCylinder("Neck", visualBody, new Vector3(0f, 1.67f, 0f), new Vector3(0.09f, 0.07f, 0.09f), materials.Skin, false);
        head = new GameObject("Head Pivot").transform;
        head.SetParent(visualBody, false);
        head.localPosition = new Vector3(0f, 1.83f, 0f);
        GameObject face = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        face.name = "Head";
        face.transform.SetParent(head, false);
        face.transform.localScale = new Vector3(0.31f, 0.39f, 0.32f);
        face.GetComponent<Renderer>().sharedMaterial = materials.Skin;
        Destroy(face.GetComponent<Collider>());
        GameObject helmet = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        helmet.name = "Tactical Helmet";
        helmet.transform.SetParent(head, false);
        helmet.transform.localPosition = new Vector3(0f, 0.08f, -0.005f);
        helmet.transform.localScale = new Vector3(0.39f, 0.30f, 0.38f);
        helmet.GetComponent<Renderer>().sharedMaterial = materials.Polymer;
        Destroy(helmet.GetComponent<Collider>());
        AuroraMaterials.CreateBox("Goggles", head, new Vector3(0f, 0.01f, 0.155f), new Vector3(0.28f, 0.085f, 0.045f), materials.Glass, false);
        AuroraMaterials.CreateBox("Headset", head, new Vector3(0.19f, 0f, 0f), new Vector3(0.06f, 0.20f, 0.18f), teamMaterial, false);

        AimPoint = new GameObject("Aim Point").transform;
        AimPoint.SetParent(visualBody, false);
        AimPoint.localPosition = new Vector3(0f, 1.53f, 0.02f);

        WeaponMount = new GameObject("Weapon Mount").transform;
        WeaponMount.SetParent(visualBody, false);
        WeaponMount.localPosition = new Vector3(0.18f, 1.30f, 0.35f);
        WeaponMount.localRotation = Quaternion.Euler(0f, 0f, 0f);
    }

    private Transform BuildLeg(string partName, float x, AuroraMaterials materials)
    {
        Transform hip = new GameObject(partName + " Hip").transform;
        hip.SetParent(visualBody, false);
        hip.localPosition = new Vector3(x, 0.91f, 0f);
        AuroraMaterials.CreateCylinder(partName + " Upper", hip, new Vector3(0f, -0.22f, 0f), new Vector3(0.115f, 0.23f, 0.115f), materials.Armor, false);
        Transform knee = new GameObject(partName + " Knee").transform;
        knee.SetParent(hip, false);
        knee.localPosition = new Vector3(0f, -0.45f, 0f);
        AuroraMaterials.CreateCylinder(partName + " Lower", knee, new Vector3(0f, -0.20f, 0f), new Vector3(0.10f, 0.21f, 0.10f), materials.Fabric, false);
        AuroraMaterials.CreateBox(partName + " Boot", knee, new Vector3(0f, -0.43f, 0.07f), new Vector3(0.22f, 0.17f, 0.34f), materials.Polymer, false);
        return hip;
    }

    private Transform BuildArm(string partName, float x, AuroraMaterials materials)
    {
        Transform shoulder = new GameObject(partName + " Shoulder").transform;
        shoulder.SetParent(visualBody, false);
        shoulder.localPosition = new Vector3(x, 1.52f, 0f);
        AuroraMaterials.CreateCylinder(partName + " Sleeve", shoulder, new Vector3(0f, -0.19f, 0f), new Vector3(0.105f, 0.20f, 0.105f), materials.Fabric, false);
        Transform elbow = new GameObject(partName + " Elbow").transform;
        elbow.SetParent(shoulder, false);
        elbow.localPosition = new Vector3(0f, -0.38f, 0f);
        elbow.localRotation = Quaternion.Euler(-28f, 0f, 0f);
        AuroraMaterials.CreateCylinder(partName + " Forearm", elbow, new Vector3(0f, -0.17f, 0f), new Vector3(0.09f, 0.18f, 0.09f), materials.Armor, false);
        GameObject glove = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        glove.name = partName + " Glove";
        glove.transform.SetParent(elbow, false);
        glove.transform.localPosition = new Vector3(0f, -0.36f, 0f);
        glove.transform.localScale = Vector3.one * 0.18f;
        glove.GetComponent<Renderer>().sharedMaterial = materials.Polymer;
        Destroy(glove.GetComponent<Collider>());
        return shoulder;
    }

    public void Animate(Vector3 localVelocity, bool aiming, float delta)
    {
        float speed = new Vector2(localVelocity.x, localVelocity.z).magnitude;
        strideTime += delta * Mathf.Lerp(4f, 10f, Mathf.Clamp01(speed / 5f));
        float stride = Mathf.Sin(strideTime) * Mathf.Clamp01(speed / 2f) * 34f;
        leftLeg.localRotation = Quaternion.Slerp(leftLeg.localRotation, Quaternion.Euler(stride, 0f, 0f), delta * 12f);
        rightLeg.localRotation = Quaternion.Slerp(rightLeg.localRotation, Quaternion.Euler(-stride, 0f, 0f), delta * 12f);

        Quaternion leftTarget = Quaternion.Euler(aiming ? -64f : -stride * 0.55f, aiming ? -12f : 0f, aiming ? -8f : 0f);
        Quaternion rightTarget = Quaternion.Euler(aiming ? -70f : stride * 0.55f, aiming ? 8f : 0f, aiming ? 9f : 0f);
        leftArm.localRotation = Quaternion.Slerp(leftArm.localRotation, leftTarget, delta * 10f);
        rightArm.localRotation = Quaternion.Slerp(rightArm.localRotation, rightTarget, delta * 10f);
        head.localRotation = Quaternion.Slerp(head.localRotation, Quaternion.Euler(aiming ? -3f : 0f, 0f, 0f), delta * 8f);
        visualBody.localPosition = Vector3.Lerp(visualBody.localPosition, new Vector3(0f, Mathf.Abs(Mathf.Sin(strideTime)) * speed * 0.003f, 0f), delta * 12f);
        visualBody.localRotation = Quaternion.Slerp(visualBody.localRotation, Quaternion.Euler(0f, 0f, -localVelocity.x * 0.75f), delta * 7f);
    }
}

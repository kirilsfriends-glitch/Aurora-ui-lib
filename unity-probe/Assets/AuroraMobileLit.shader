Shader "Aurora/MobileLit"
{
    Properties
    {
        _Color ("Base Color", Color) = (1,1,1,1)
        _EmissionColor ("Emission", Color) = (0,0,0,0)
        _Smoothness ("Smoothness", Range(0,1)) = 0.35
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 120

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            fixed4 _Color;
            fixed4 _EmissionColor;
            half _Smoothness;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                half3 worldNormal : TEXCOORD0;
                half3 worldView : TEXCOORD1;
                UNITY_FOG_COORDS(2)
            };

            v2f vert(appdata input)
            {
                v2f output;
                output.position = UnityObjectToClipPos(input.vertex);
                float3 worldPosition = mul(unity_ObjectToWorld, input.vertex).xyz;
                output.worldNormal = UnityObjectToWorldNormal(input.normal);
                output.worldView = normalize(_WorldSpaceCameraPos.xyz - worldPosition);
                UNITY_TRANSFER_FOG(output, output.position);
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                half3 normal = normalize(input.worldNormal);
                half3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                half diffuse = saturate(dot(normal, lightDirection));
                half3 halfDirection = normalize(lightDirection + normalize(input.worldView));
                half specular = pow(saturate(dot(normal, halfDirection)), lerp(8.0h, 48.0h, _Smoothness));
                half3 ambient = half3(0.38h, 0.43h, 0.48h);
                half3 lighting = ambient + _LightColor0.rgb * (diffuse * 0.74h + specular * 0.18h * _Smoothness);
                fixed4 color = fixed4(_Color.rgb * lighting + _EmissionColor.rgb, _Color.a);
                UNITY_APPLY_FOG(input.fogCoord, color);
                return color;
            }
            ENDCG
        }

        Pass
        {
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            CGPROGRAM
            #pragma vertex vertShadow
            #pragma fragment fragShadow
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"
            struct vertexInput { float4 vertex : POSITION; float3 normal : NORMAL; };
            struct vertexOutput { V2F_SHADOW_CASTER; };
            vertexOutput vertShadow(vertexInput v)
            {
                vertexOutput o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }
            float4 fragShadow(vertexOutput i) : SV_Target { SHADOW_CASTER_FRAGMENT(i) }
            ENDCG
        }
    }
    Fallback Off
}

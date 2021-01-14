Shader "Custom/HairShadowSoild"
{
    Properties
    {
        _BaseColor ("Color", Color) = (0, 0.66, 0.73, 1)
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }
        
        
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseColor;
        CBUFFER_END
        ENDHLSL
        
        Pass
        {
            Name "HairSimpleColor"
            Tags { "LightMode" = "UniversalForward" }
            
            Cull Back
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            struct a2v
            {
                float4 positionOS: POSITION;
                float4 color: COLOR;
            };
            
            struct v2f
            {
                float4 positionCS: SV_POSITION;
                float4 color: COLOR;
            };
            
            
            v2f vert(a2v v)
            {
                v2f o;
                
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positionInputs.positionCS;
                o.color = v.color;
                return o;
            }
            
            half4 frag(v2f i): SV_Target
            {
                //if (depth =  z/w * 0.5 + 0.5), we will have a float precision problem
                //but it's just right when we are far away from character to hide the shadow
                //float depth = (i.positionCS.z / i.positionCS.w) * 0.5 + 0.5;
                float depth = (i.positionCS.z / i.positionCS.w);
                
                return float4(0, depth, 0, 1);
            }
            ENDHLSL
            
        }
        
        Pass
        {
            Name "FaceDepthOnly"
            Tags { "LightMode" = "UniversalForward" }
            
            ColorMask 0
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            struct a2v
            {
                float4 positionOS: POSITION;
            };
            
            struct v2f
            {
                float4 positionCS: SV_POSITION;
            };
            
            
            v2f vert(a2v v)
            {
                v2f o;
                
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                return o;
            }
            
            half4 frag(v2f i): SV_Target
            {
                return (0, 0, 0, 1);
            }
            ENDHLSL
            
        }

    }
}
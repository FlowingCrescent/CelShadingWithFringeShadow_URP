Shader "Custom/HairShadowSoild"
{
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
            
            Cull Off
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
                //In DirectX, z/w from [0, 1], and use reversed Z
                //So, it means we aren't adapt the sample for OpenGL platform
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
                return(0, 0, 0, 1);
            }
            ENDHLSL
            
        }
    }
}
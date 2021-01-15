Shader "Custom/CelShadingWithFringeShadow"
{
    Properties
    {
        [MainTexture]_BaseMap ("Base Map", 2D) = "white" { }
        _BaseColor ("Base Color", Color) = (0, 0.66, 0.73, 1)
        
        [Header(Shading)]
        _BrightColor ("BrightColor", Color) = (1, 1, 1, 1)
        [HDR]_MiddleColor ("MiddleColor", Color) = (0.8, 0.1, 0.1, 1)
        _DarkColor ("DarkColor", Color) = (0.5, 0.5, 0.5, 1)
        _CelShadeMidPoint ("CelShadeMidPoint", Range(0, 1)) = 0.5
        _CelShadeSmoothness ("CelShadeSmoothness", Range(0, 1)) = 0.1
        [Toggle(_IsFace)] _IsFace ("IsFace", Float) = 0.0
        _HairShadowDistace ("_HairShadowDistance", Float) = 1
        
        [Header(Rim)]
        _RimColor ("RimColor", Color) = (1, 1, 1, 1)
        _RimSmoothness ("RimSmoothness", Range(0, 10)) = 10
        _RimStrength ("RimStrength", Range(0, 1)) = 0.1
        
        [Header(OutLine)]
        _OutLineColor ("OutLineColor", Color) = (0, 0, 0, 1)
        _OutLineThickness ("OutLineThickness", float) = 0.5
        [Toggle(_UseColor)] _UseColor ("UseVertexColor", Float) = 0.0
        
        [Header(heightCorrectMask)]
        _HeightCorrectMax ("HeightCorrectMax", float) = 1.6
        _HeightCorrectMin ("HeightCorrectMin", float) = 1.51
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
        
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT
        
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        float4 _BaseColor, _BrightColor, _DarkColor, _OutLineColor, _MiddleColor, _RimColor;
        float _CelShadeMidPoint, _CelShadeSmoothness, _OutLineThickness;
        float _RimSmoothness, _RimStrength, _HairShadowDistace, _HeightCorrectMax, _HeightCorrectMin;
        
        
        CBUFFER_END
        ENDHLSL
        
        Pass
        {
            Name "BaseCel"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _IsFace
            
            
            struct a2v
            {
                float4 positionOS: POSITION;
                float2 uv: TEXCOORD0;
                float4 normal: NORMAL;
                float3 color: COLOR;
            };
            
            struct v2f
            {
                float4 positionCS: SV_POSITION;
                float2 uv: TEXCOORD0;
                float3 positionWS: TEXCOORD1;
                float3 normal: TEXCOORD2;
                #if _IsFace
                    float4 positionSS: TEXCOORD3;
                    float posNDCw: TEXCOORD4;
                    float4 positionOS: TEXCOORD5;
                #endif
                
                float3 color: TEXCOORD6;
            };
            
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_HairSoildColor);
            SAMPLER(sampler_HairSoildColor);
            
            v2f vert(a2v v)
            {
                v2f o;
                
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positionInputs.positionCS;
                o.positionWS = positionInputs.positionWS;
                
                #if _IsFace
                    o.posNDCw = positionInputs.positionNDC.w;
                    o.positionSS = ComputeScreenPos(positionInputs.positionCS);
                    o.positionOS = v.positionOS;
                #endif
                
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(v.normal.xyz);
                o.normal = vertexNormalInput.normalWS;
                
                o.color = v.color;
                return o;
            }
            
            
            half4 frag(v2f i): SV_Target
            {
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS.xyz);
                Light light = GetMainLight(shadowCoord);
                float3 normal = normalize(i.normal);
                
                //get light and receive shadow
                Light mainLight;
                #if _MAIN_LIGHT_SHADOWS
                    mainLight = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                #else
                    mainLight = GetMainLight();
                #endif
                real shadow = mainLight.shadowAttenuation * mainLight.distanceAttenuation;
                
                //basic cel shading
                float CelShadeMidPoint = _CelShadeMidPoint;
                float halfLambert = dot(normal, light.direction) * 0.5 + 0.5;
                half ramp = smoothstep(0, CelShadeMidPoint, pow(saturate(halfLambert - CelShadeMidPoint), _CelShadeSmoothness));
                
                
                //face shadow
                #if _IsFace
                    //"heightCorrect" is a easy mask which used to deal with some extreme view angles,
                    //you can delete it if you think it's unnecessary.
                    //you also can use it to adjust the shadow length, if you want.
                    float heightCorrect = smoothstep(_HeightCorrectMax, _HeightCorrectMin, i.positionWS.y);
                    
                    //In DirectX, z/w from [0, 1], and use reversed Z
                    //So, it means we aren't adapt the sample for OpenGL platform
                    float depth = (i.positionCS.z / i.positionCS.w);
                    
                    //get linearEyeDepth which we can using easily
                    float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams);
                    float2 scrPos = i.positionSS.xy / i.positionSS.w;
                    
                    //"min(1, 5/linearEyeDepth)" is a curve to adjust viewLightDir.length by distance
                    float3 viewLightDir = normalize(TransformWorldToViewDir(mainLight.direction)) * (1 / min(i.posNDCw, 1)) * min(1, 5 / linearEyeDepth) /** heightCorrect*/;
                    
                    //get the final sample point
                    float2 samplingPoint = scrPos + _HairShadowDistace * viewLightDir.xy;
                    
                    float hairDepth = SAMPLE_TEXTURE2D(_HairSoildColor, sampler_HairSoildColor, samplingPoint).g;
                    hairDepth = LinearEyeDepth(hairDepth, _ZBufferParams);
                    
                    //0.01 is bias
                    float depthContrast = linearEyeDepth  > hairDepth * heightCorrect - 0.01 ? 0: 1;
                    
                    //deprecated
                    //float hairShadow = 1 - SAMPLE_TEXTURE2D(_HairSoildColor, sampler_HairSoildColor, samplingPoint).r;
                    
                    //0 is shadow part, 1 is bright part
                    ramp *= depthContrast;
                #else
                    
                    ramp *= shadow;
                    
                #endif
                
                
                float3 diffuse = lerp(_DarkColor.rgb, _BrightColor.rgb, ramp);
                diffuse *= baseMap.rgb;
                
                //rim light
                float3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - i.positionWS.xyz);
                float rimStrength = pow(saturate(1 - dot(normal, viewDirectionWS)), _RimSmoothness);
                float3 rimColor = _RimColor.rgb * rimStrength * _RimStrength;
                
                return float4(diffuse + rimColor, 1);
                return baseMap * _BaseColor;
            }
            ENDHLSL
            
        }
        
        //easy outline pass
        Pass
        {
            Name "OutLine"
            Cull Front
            ZWrite On
            
            HLSLPROGRAM
            
            #pragma shader_feature _UseColor
            #pragma vertex vert
            #pragma fragment frag
            
            struct a2v
            {
                float4 positionOS: POSITION;
                float4 normalOS: NORMAL;
                float4 tangentOS: TANGENT;
                #if _UseColor
                    float3 color: COLOR;
                #endif
            };
            
            struct v2f
            {
                float4 positionCS: SV_POSITION;
            };
            
            v2f vert(a2v v)
            {
                v2f o;
                
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                
                #if _UseColor
                    float3 color = v.color * 2 - 1;
                    
                    VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz + float3(color.xy * 0.001 * _OutLineThickness, 0));
                    o.positionCS = positionInputs.positionCS;
                #else
                    float3 normalWS = vertexNormalInput.normalWS;
                    float3 normalCS = TransformWorldToHClipDir(normalWS);
                    
                    VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                    o.positionCS = positionInputs.positionCS + float4(normalCS.xy * 0.001 * _OutLineThickness * positionInputs.positionCS.w, 0, 0);
                #endif
                
                
                
                return o;
            }
            
            half4 frag(v2f i): SV_Target
            {
                float4 col = _OutLineColor;
                
                return col;
            }
            ENDHLSL
            
        }
        
        //this Pass copy from https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            //we don't care about color, we just write to depth
            ColorMask 0
            
            HLSLPROGRAM
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            #pragma vertex ShadowCasterPassVertex
            #pragma fragment ShadowCasterPassFragment
            
            struct Attributes
            {
                float3 positionOS: POSITION;
                half3 normalOS: NORMAL;
                half4 tangentOS: TANGENT;
                float2 uv: TEXCOORD0;
            };
            
            struct Varyings
            {
                float2 uv: TEXCOORD0;
                float4 positionWSAndFogFactor: TEXCOORD2; // xyz: positionWS, w: vertex fog factor
                half3 normalWS: TEXCOORD3;
                
                #ifdef _MAIN_LIGHT_SHADOWS
                    float4 shadowCoord: TEXCOORD6; // compute shadow coord per-vertex for the main light
                #endif
                float4 positionCS: SV_POSITION;
            };
            
            Varyings ShadowCasterPassVertex(Attributes input)
            {
                Varyings output;
                
                // VertexPositionInputs contains position in multiple spaces (world, view, homogeneous clip space)
                // Our compiler will strip all unused references (say you don't use view space).
                // Therefore there is more flexibility at no additional cost with this struct.
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS);
                
                // Similar to VertexPositionInputs, VertexNormalInputs will contain normal, tangent and bitangent
                // in world space. If not used it will be stripped.
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                
                // Computes fog factor per-vertex.
                float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                
                // TRANSFORM_TEX is the same as the old shader library.
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                
                // packing posWS.xyz & fog into a vector4
                output.positionWSAndFogFactor = float4(vertexInput.positionWS, fogFactor);
                output.normalWS = vertexNormalInput.normalWS;
                
                #ifdef _MAIN_LIGHT_SHADOWS
                    // shadow coord for the light is computed in vertex.
                    // After URP 7.21, URP will always resolve shadows in light space, no more screen space resolve.
                    // In this case shadowCoord will be the vertex position in light space.
                    output.shadowCoord = GetShadowCoord(vertexInput);
                #endif
                
                // Here comes the flexibility of the input structs.
                // We just use the homogeneous clip position from the vertex input
                output.positionCS = vertexInput.positionCS;
                
                // ShadowCaster pass needs special process to clipPos, else shadow artifact will appear
                //--------------------------------------------------------------------------------------
                
                //see GetShadowPositionHClip() in URP/Shaders/ShadowCasterPass.hlsl
                float3 positionWS = vertexInput.positionWS;
                float3 normalWS = vertexNormalInput.normalWS;
                
                
                Light light = GetMainLight();
                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, light.direction));
                
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                output.positionCS = positionCS;
                
                //--------------------------------------------------------------------------------------
                
                return output;
            }
            
            half4 ShadowCasterPassFragment(Varyings input): SV_TARGET
            {
                return 0;
            }
            
            ENDHLSL
            
        }
    }
}
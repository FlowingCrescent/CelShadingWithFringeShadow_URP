using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CelHairShadow : ScriptableRendererFeature
{
    [System.Serializable]
    public class Setting
    {
        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingOpaques;
        public LayerMask hairLayer;
        public LayerMask faceLayer;
        [Range(1000, 5000)]
        public int queueMin = 2000;

        [Range(1000, 5000)]
        public int queueMax = 3000;
        public Material material;

    }
    public Setting setting = new Setting();
    class CustomRenderPass : ScriptableRenderPass
    {
        public int soildColorID = 0;
        public ShaderTagId shaderTag = new ShaderTagId("UniversalForward");
        public Setting setting;
        
        FilteringSettings filtering;
        FilteringSettings filtering2;
        public CustomRenderPass(Setting setting)
        {
            this.setting = setting;

            RenderQueueRange queue = new RenderQueueRange();
            queue.lowerBound = Mathf.Min(setting.queueMax, setting.queueMin);
            queue.upperBound = Mathf.Max(setting.queueMax, setting.queueMin);
            filtering = new FilteringSettings(queue, setting.hairLayer);
            filtering2 = new FilteringSettings(queue, setting.faceLayer);
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            //get a ID
            int temp = Shader.PropertyToID("_HairSoildColor");
            //use the same settings as the camera texture
            RenderTextureDescriptor desc = cameraTextureDescriptor;
            cmd.GetTemporaryRT(temp, desc);
            soildColorID = temp;
            //set the RT as Render Target
            ConfigureTarget(temp);
            //clear the RT
            ConfigureClear(ClearFlag.All, Color.black);

        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            /*
            var draw1 = CreateDrawingSettings(shaderTag, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags);
            draw1.overrideMaterial = setting.material;
            draw1.overrideMaterialPassIndex = 1;
            context.DrawRenderers(renderingData.cullResults, ref draw1, ref filtering2);*/

            var draw2 = CreateDrawingSettings(shaderTag, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags);
            draw2.overrideMaterial = setting.material;
            draw2.overrideMaterialPassIndex = 0;
            context.DrawRenderers(renderingData.cullResults, ref draw2, ref filtering);

        }


        public override void FrameCleanup(CommandBuffer cmd)
        {

        }
    }

    CustomRenderPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(setting);

        m_ScriptablePass.renderPassEvent = setting.passEvent;
    }


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
}



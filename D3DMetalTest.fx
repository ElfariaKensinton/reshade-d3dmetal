#include "ReShade.fxh"
float4 TestPS(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
 float3 c = tex2D(ReShade::BackBuffer, uv).rgb;
 return float4(lerp(c, c.bgr, 0.85), 1.0);
}
technique D3DMetalTest { pass { VertexShader = PostProcessVS; PixelShader = TestPS; } }

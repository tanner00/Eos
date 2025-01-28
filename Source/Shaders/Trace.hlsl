struct RootConstants
{
	uint OutputTextureIndex;
};
ConstantBuffer<RootConstants> RootConstants : register(b0);

[numthreads(1, 1, 1)]
void ComputeStart(uint3 dispatchThreadID : SV_DispatchThreadID)
{
	const RWTexture2D<float3> outputTexture = ResourceDescriptorHeap[RootConstants.OutputTextureIndex];

	const uint x = dispatchThreadID.x;
	const uint y = dispatchThreadID.y;

	outputTexture[uint2(x, y)] = float3(0.0f, 0.0f, 0.0f);
}

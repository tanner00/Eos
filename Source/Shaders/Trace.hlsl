struct RootConstants
{
	uint OutputTextureIndex;
};
ConstantBuffer<RootConstants> RootConstants : register(b0);

static const float viewportHeight = 2.0f;
static const float focalLength = 1.0f;

bool RaySphere(float3 rayOrigin, float3 rayDirection, float3 sphereCenter, float sphereRadius)
{
	const float3 offset = sphereCenter - rayOrigin;
	const float a = dot(rayDirection, rayDirection);
	const float b = -2.0f * dot(rayDirection, offset);
	const float c = dot(offset, offset) - sphereRadius * sphereRadius;
	const float discriminant = b * b - 4.0f * a * c;
	return discriminant >= 0.0f;
}

[numthreads(1, 1, 1)]
void ComputeStart(uint3 dispatchThreadID : SV_DispatchThreadID)
{
	const uint x = dispatchThreadID.x;
	const uint y = dispatchThreadID.y;

	const RWTexture2D<float3> outputTexture = ResourceDescriptorHeap[RootConstants.OutputTextureIndex];

	uint outputTextureWidth;
	uint outputTextureHeight;
	outputTexture.GetDimensions(outputTextureWidth, outputTextureHeight);

	const float aspectRatio = (float)outputTextureWidth / outputTextureHeight;

	const float viewportWidth = viewportHeight * aspectRatio;

	const float3 viewportU = float3(viewportWidth, 0.0f, 0.0f);
	const float3 viewportV = float3(0.0f, -viewportHeight, 0.0f);

	const float3 pixelDeltaU = viewportU / outputTextureWidth;
	const float3 pixelDeltaV = viewportV / outputTextureHeight;
	const float3 pixelCenter = 0.5f * (pixelDeltaU + pixelDeltaV);

	const float3 cameraCenter = 0.0f;
	const float3 viewportTopLeft = cameraCenter - float3(0.0f, 0.0f, focalLength) - (viewportU / 2.0f) - (viewportV / 2.0f);
	const float3 viewportPixel = viewportTopLeft + pixelCenter + (pixelDeltaU * x + pixelDeltaV * y);

	const float3 rayOffset = viewportPixel - cameraCenter;
	const float3 rayDirection = normalize(rayOffset);

	const float alpha = 0.5f * (rayDirection.y + 1.0f);
	const float3 backgroundColor = float3(1.0f, 1.0f, 1.0f) * (1.0f - alpha) + float3(0.5f, 0.7f, 1.0f) * alpha;

	const float3 sphereCenter = float3(0.0f, 0.0f, -1.0f);
	const float sphereRadius = 0.5f;

	const float3 outputColor = RaySphere(cameraCenter, rayDirection, sphereCenter, sphereRadius) ? float3(1.0f, 0.0f, 0.0f) : backgroundColor;

	outputTexture[uint2(x, y)] = outputColor;
}

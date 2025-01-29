static float Infinity = 1.#INF;

struct RootConstants
{
	uint OutputTextureIndex;

	float FieldOfViewYRadians;
	float FocalLength;

	matrix Orientation;
	float3 Position;
};
ConstantBuffer<RootConstants> RootConstants : register(b0);

struct Hit
{
	float Time;
	float3 Point;
	float3 Normal;
};

bool IsValidHit(Hit hit)
{
	return hit.Time >= 0.0f;
}

Hit RaySphere(float3 rayOrigin, float3 rayDirection, float rayMinT, float rayMaxT, float3 sphereCenter, float sphereRadius)
{
	const float3 offset = sphereCenter - rayOrigin;
	const float a = dot(rayDirection, rayDirection);
	const float b = -2.0f * dot(rayDirection, offset);
	const float c = dot(offset, offset) - sphereRadius * sphereRadius;
	const float discriminant = b * b - 4.0f * a * c;

	float time = -1.0f;
	if (discriminant >= 0.0f)
	{
		const float firstHit = (-b - sqrt(discriminant)) / (2.0f * a);
		const bool firstHitValid = firstHit >= rayMinT && firstHit <= rayMaxT;

		const float secondHit = (-b + sqrt(discriminant)) / (2.0f * a);
		const bool secondHitValid = secondHit >= rayMinT && secondHit <= rayMaxT;

		time = firstHitValid ? firstHit : (secondHitValid ? secondHit : time);
	}

	Hit hit;
	hit.Time = time;
	hit.Point = (rayOrigin + rayDirection * time) - sphereCenter;
	hit.Normal = hit.Point / sphereRadius;
	return hit;
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

	const float viewportHeight = 2.0f * tan(RootConstants.FieldOfViewYRadians / 2.0f) * RootConstants.FocalLength;
	const float viewportWidth = viewportHeight * aspectRatio;

	const matrix view = transpose(RootConstants.Orientation);
	const float3 cameraX = view._m00_m01_m02;
	const float3 cameraY = view._m10_m11_m12;
	const float3 cameraZ = view._m20_m21_m22;

	const float3 viewportX = viewportWidth * cameraX;
	const float3 viewportY = viewportHeight * -cameraY;

	const float3 viewportDeltaX = viewportX / outputTextureWidth;
	const float3 viewportDeltaY = viewportY / outputTextureHeight;
	const float3 pixelCenter = 0.5f * (viewportDeltaX + viewportDeltaY);

	const float3 viewportTopLeft = RootConstants.Position - (RootConstants.FocalLength * cameraZ) - (viewportX / 2.0f) - (viewportY / 2.0f);
	const float3 viewportPixel = viewportTopLeft + pixelCenter + (viewportDeltaX * x + viewportDeltaY * y);

	const float3 rayOffset = viewportPixel - RootConstants.Position;
	const float3 rayDirection = normalize(rayOffset);

	const float alpha = 0.5f * (rayDirection.y + 1.0f);
	const float3 backgroundColor = lerp(float3(1.0f, 1.0f, 1.0f), float3(0.5f, 0.7f, 1.0f), alpha);

	const float3 sphereCenter = float3(0.0f, 0.0f, -1.0f);
	const float sphereRadius = 0.5f;

	const Hit hit = RaySphere(RootConstants.Position, rayDirection, 0.0f, Infinity, sphereCenter, sphereRadius);
	const float3 outputColor = IsValidHit(hit) ? (hit.Normal * 0.5f + 0.5f) : backgroundColor;

	outputTexture[uint2(x, y)] = outputColor;
}

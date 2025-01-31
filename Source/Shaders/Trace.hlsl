#include "Common.hlsli"

static const uint SamplesPerPixel = 8;
static const uint MaxDepth = 10;

static const float3 BackgroundColor = float3(0.4f, 0.6f, 0.9f);

struct RootConstants
{
	uint OutputTextureIndex;

	float FieldOfViewYRadians;
	float FocalLength;

	matrix Orientation;
	float3 Position;
};
ConstantBuffer<RootConstants> RootConstants : register(b0);

struct Sphere
{
	float3 Position;
	float Radius;
};

static const uint SpheresCount = 3;
static const Sphere Spheres[SpheresCount] =
{
	{ float3(0.0f, 0.0f, -2.0f), 0.5f },
	{ float3(0.0f, 0.0f, -1.0f), 0.5f },
	{ float3(0.0f, -50.5f, -1.0f), 50.0f },
};

struct Hit
{
	float Time;
	float3 Point;
	float3 Normal;
	bool FrontFace;
};

bool IsValidHit(Hit hit)
{
	return hit.Time >= 0.0f;
}

Hit RaySphere(float3 rayOrigin, float3 rayDirection, float rayMinT, float rayMaxT, float3 sphereCenter, float sphereRadius)
{
	const float3 rayToSphereOffset = sphereCenter - rayOrigin;
	const float a = dot(rayDirection, rayDirection);
	const float b = -2.0f * dot(rayDirection, rayToSphereOffset);
	const float c = dot(rayToSphereOffset, rayToSphereOffset) - sphereRadius * sphereRadius;
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

	const float3 hitPoint = rayOrigin + rayDirection * time;
	const float3 outwardNormal = (hitPoint - sphereCenter) / sphereRadius;
	const bool frontFace = dot(rayDirection, outwardNormal) <= 0.0f;

	Hit hit;
	hit.Time = time;
	hit.Point = hitPoint;
	hit.Normal = frontFace ? outwardNormal : -outwardNormal;
	hit.FrontFace = frontFace;
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

	const uint dispatchThreadIndex = y * outputTextureWidth + x;

	uint rngState = dispatchThreadIndex;
	PcgRandom(rngState);

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

	float3 samples = 0.0f;
	for (uint i = 0; i < SamplesPerPixel; ++i)
	{
		const float2 sampleOffset = float2(Random01(rngState) - 0.5f, Random01(rngState) - 0.5f);
		const float3 viewportPixel = viewportTopLeft + pixelCenter + (viewportDeltaX * (x + sampleOffset.x) + viewportDeltaY * (y + sampleOffset.y));

		float3 rayOrigin = RootConstants.Position;
		float3 rayDirection = normalize(viewportPixel - RootConstants.Position);
		uint depth = 0;

		float3 color = BackgroundColor;
		while (depth != MaxDepth)
		{
			Hit hit = (Hit)0;
			hit.Time = -1.0f;
			for (uint j = 0; j < SpheresCount; ++j)
			{
				const Sphere sphere = Spheres[j];

				const Hit potentialHit = RaySphere(rayOrigin, rayDirection, 0.0001f, Infinity, sphere.Position, sphere.Radius);
				const bool closer = potentialHit.Time < hit.Time;
				if (IsValidHit(potentialHit) && (closer || !IsValidHit(hit)))
				{
					hit = potentialHit;
				}
			}

			if (IsValidHit(hit))
			{
				const float3 material = color * 0.5f;
				color = material;

				rayDirection = RandomHemisphere(rngState, hit.Normal);
				rayOrigin = hit.Point;

				++depth;
			}
			else
			{
				break;
			}
		}
		samples += color;
	}

	const float3 outputColor = samples / SamplesPerPixel;
	outputTexture[uint2(x, y)] = outputColor;
}

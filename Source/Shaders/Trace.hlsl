#include "Common.hlsli"

static const uint SamplesPerPixel = 1;
static const uint MaxDepth = 10;

static const float FieldOfViewYRadians = Pi / 9.0f;
static const float FocalLength = 1.0f;

static const float3 BackgroundColor = float3(0.4f, 0.6f, 0.9f);

struct RootConstants
{
	matrix Orientation;
	float3 Position;

	uint FrameIndex;

	uint OutputTextureIndex;

	uint SpheresBuffer;
	uint SpheresBufferCount;
};
ConstantBuffer<RootConstants> RootConstants : register(b0);

enum class MaterialType : uint
{
	Lambertian,
	Metallic,
	Dielectric,
};

struct Material
{
	MaterialType Type;

	// Lambertian & Metallic
	float3 Albedo;

	// Dielectric
	float RefractionIndex;
};

struct Sphere
{
	float3 Position;
	float Radius;
	Material Material;
};

struct Hit
{
	float Time;
	float3 Point;
	float3 Normal;
	bool FrontFace;
	Material Material;
};

bool IsValidHit(Hit hit)
{
	return hit.Time >= 0.0f;
}

Hit RaySphere(float3 rayOrigin, float3 rayDirection, float rayMinT, float rayMaxT, Sphere sphere)
{
	const float3 rayToSphereOffset = sphere.Position - rayOrigin;
	const float a = dot(rayDirection, rayDirection);
	const float b = -2.0f * dot(rayDirection, rayToSphereOffset);
	const float c = dot(rayToSphereOffset, rayToSphereOffset) - sphere.Radius * sphere.Radius;
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
	const float3 outwardNormal = (hitPoint - sphere.Position) / sphere.Radius;
	const bool frontFace = dot(rayDirection, outwardNormal) <= 0.0f;

	Hit hit;
	hit.Time = time;
	hit.Point = hitPoint;
	hit.Normal = frontFace ? outwardNormal : -outwardNormal;
	hit.FrontFace = frontFace;
	hit.Material = sphere.Material;
	return hit;
}

void Scatter(inout uint rngState, inout float3 rayDirection, inout float3 attenuation, Hit hit)
{
	switch (hit.Material.Type)
	{
	case MaterialType::Lambertian:
	{
		attenuation *= hit.Material.Albedo;
		rayDirection = normalize(hit.Normal + RandomUnitVector(rngState));
		if (any(isnan(rayDirection)))
		{
			rayDirection = hit.Normal;
		}
		break;
	}
	case MaterialType::Metallic:
	{
		attenuation *= hit.Material.Albedo;
		rayDirection = Reflect(rayDirection, hit.Normal);
		break;
	}
	case MaterialType::Dielectric:
	{
		const float index = hit.FrontFace ? (1.0f / hit.Material.RefractionIndex) : hit.Material.RefractionIndex;

		const float cosTheta = min(dot(-rayDirection, hit.Normal), 1.0f);
		const float sinTheta = sqrt(1.0f - cosTheta * cosTheta);

		const float r0 = pow((1.0f - index) / (1.0f + index), 2.0f);
		const float schlick = r0 + (1.0f - r0) * pow((1.0f - cosTheta), 5.0f);

		const bool cannotRefract = index * sinTheta > 1.0f;
		if (cannotRefract || schlick > Random01(rngState))
		{
			rayDirection = Reflect(rayDirection, hit.Normal);
		}
		else
		{
			rayDirection = Refract(rayDirection, hit.Normal, index);
		}
		break;
	}
	}
}

[numthreads(8, 8, 1)]
void ComputeStart(uint3 dispatchThreadID : SV_DispatchThreadID)
{
	const uint x = dispatchThreadID.x;
	const uint y = dispatchThreadID.y;

	const RWTexture2D<float3> outputTexture = ResourceDescriptorHeap[RootConstants.OutputTextureIndex];

	const StructuredBuffer<Sphere> spheres = ResourceDescriptorHeap[RootConstants.SpheresBuffer];

	uint outputTextureWidth;
	uint outputTextureHeight;
	outputTexture.GetDimensions(outputTextureWidth, outputTextureHeight);

	const uint dispatchThreadIndex = y * outputTextureWidth + x;

	uint rngState = Hash(dispatchThreadIndex * RootConstants.FrameIndex);
	RandomPcg(rngState);

	const float aspectRatio = (float)outputTextureWidth / outputTextureHeight;

	const float viewportHeight = 2.0f * tan(FieldOfViewYRadians / 2.0f) * FocalLength;
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

	const float3 viewportTopLeft = RootConstants.Position - (FocalLength * cameraZ) - (viewportX / 2.0f) - (viewportY / 2.0f);

	float3 samples = 0.0f;
	for (uint i = 0; i < SamplesPerPixel; ++i)
	{
		const float2 sampleOffset = float2(Random01(rngState) - 0.5f, Random01(rngState) - 0.5f);
		const float3 viewportPixel = viewportTopLeft + pixelCenter + viewportDeltaX * (x + sampleOffset.x) + viewportDeltaY * (y + sampleOffset.y);

		float3 rayOrigin = RootConstants.Position;
		float3 rayDirection = normalize(viewportPixel - RootConstants.Position);
		uint depth = 0;

		float3 color = BackgroundColor;
		while (depth != MaxDepth)
		{
			Hit hit = (Hit)0;
			hit.Time = -1.0f;
			for (uint j = 0; j < RootConstants.SpheresBufferCount; ++j)
			{
				const Sphere sphere = spheres[j];

				const Hit potentialHit = RaySphere(rayOrigin, rayDirection, 0.001f, Infinity, sphere);
				const bool closer = potentialHit.Time < hit.Time;
				if (IsValidHit(potentialHit) && (closer || !IsValidHit(hit)))
				{
					hit = potentialHit;
				}
			}

			if (IsValidHit(hit))
			{
				Scatter(rngState, rayDirection, color, hit);
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

	const float3 previousColor = SrgbToLinear(outputTexture[uint2(x, y)]);
	const float3 newColor = samples / SamplesPerPixel;
	const float3 accumulatedColor = lerp(previousColor, newColor, 1.0f / (1.0f + RootConstants.FrameIndex));

	outputTexture[uint2(x, y)] = LinearToSrgb(accumulatedColor);
}

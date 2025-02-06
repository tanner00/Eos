static const float Infinity = 1.#INF;

static const float Pi = 3.14159265358979323846f;

float3 LinearToSrgb(float3 x)
{
	return select(x < 0.0031308f, x * 12.92f, (pow(x, 1.0f / 2.4f) * 1.055f) - 0.055f);
}

float3 SrgbToLinear(float3 x)
{
	return select(x < 0.04045f, x / 12.92f, pow((x + 0.055f) / 1.055f, 2.4f));
}

float3 Reflect(float3 incoming, float3 normal)
{
	return incoming - 2.0f * dot(incoming, normal) * normal;
}

float3 Refract(float3 incoming, float3 normal, float refractionIndex)
{
	const float cosTheta = min(dot(-incoming, normal), 1.0f);
	const float3 outPerpendicular = refractionIndex * (incoming + cosTheta * normal);
	const float3 outParallel = -sqrt(abs(1.0f - dot(outPerpendicular, outPerpendicular))) * normal;
	return outPerpendicular + outParallel;
}

uint Hash(uint v)
{
	v ^= 2747636419;
	v *= 2654435769;
	v ^= v >> 16;
	v *= 2654435769;
	v ^= v >> 16;
	v *= 2654435769;
	return v;
}

uint RandomPcg(inout uint rngState)
{
	const uint state = rngState;
	rngState = rngState * 747796405U + 2891336453U;
	const uint word = ((state >> ((state >> 28U) + 4U)) ^ state) * 277803737U;
	return (word >> 22U) ^ word;
}

float Random01(inout uint rngState)
{
	return (float)RandomPcg(rngState) / (float)0xFFFFFFFF;
}

float Random(inout uint rngState, float min, float max)
{
	return lerp(min, max, Random01(rngState));
}

float3 RandomUnitVector(inout uint rngState)
{
	float3 x;
	while (true)
	{
		x = float3(Random(rngState, -1.0f, 1.0f), Random(rngState, -1.0f, 1.0f), Random(rngState, -1.0f, 1.0f));
		const float lengthSquared = dot(x, x);
		if (1e-20 <= lengthSquared && lengthSquared <= 1.0f)
		{
			break;
		}
	}
	return normalize(x);
}

float3 RandomHemisphere(inout uint rngState, float3 normal)
{
	const float3 x = RandomUnitVector(rngState);
	return dot(x, normal) > 0.0f ? x : -x;
}

static const float Infinity = 1.#INF;

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

uint PcgRandom(inout uint rngState)
{
	const uint state = rngState;
	rngState = rngState * 747796405u + 2891336453u;
	const uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float Random01(inout uint rngState)
{
	static const float uintMax = 2 << 31;
	return (float)PcgRandom(rngState) / (uintMax + 1.0f);
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

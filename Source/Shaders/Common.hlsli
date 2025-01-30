static const float Infinity = 1.#INF;

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

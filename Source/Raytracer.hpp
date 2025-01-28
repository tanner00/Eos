#pragma once

#include "Luft/Base.hpp"
#include "Luft/NoCopy.hpp"

#include "RHI/GpuDevice.hpp"

struct RootConstants
{
	uint32 OutputTextureIndex;

	PAD(252);
};

class Raytracer : public NoCopy
{
public:
	explicit Raytracer(const Platform::Window* window);
	~Raytracer();

	void Update();

	void Resize(uint32 width, uint32 height);

private:
	void CreatePipelines();
	void DestroyPipelines();

	void CreateScreenTextures(uint32 width, uint32 height);
	void DestroyScreenTextures();

	GpuDevice Device;
	GraphicsContext Graphics;

	ComputePipeline TracePipeline;

	Texture SwapChainTextures[FramesInFlight];
	Texture OutputTexture;

	double AverageGpuTime;
};

#pragma once

#include "RHI/GpuDevice.hpp"

#include "Luft/Base.hpp"
#include "Luft/Math.hpp"
#include "Luft/NoCopy.hpp"

class CameraController;

struct RootConstants
{
	Matrix Orientation;
	Float3 Position;

	uint32 OutputTextureIndex;

	PAD(176);
};

class Raytracer : public NoCopy
{
public:
	explicit Raytracer(const Platform::Window* window);
	~Raytracer();

	void Update(const CameraController& cameraController);

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

#pragma once

#include "RHI/GpuDevice.hpp"

#include "Luft/Base.hpp"
#include "Luft/Math.hpp"
#include "Luft/NoCopy.hpp"

class CameraController;

namespace Hlsl
{

enum class MaterialType : uint32
{
	Lambertian,
	Metallic,
	Dielectric,
};

struct Material
{
	MaterialType Type;

	Float3 Albedo;

	float RefractionIndex;
};

struct Sphere
{
	Float3 Position;
	float Radius;
	Material Material;
};

struct TraceRootConstants
{
	Matrix Orientation;
	Float3 Position;

	uint32 OutputTextureIndex;

	uint32 SpheresBufferIndex;
	uint32 SpheresBufferCount;

	PAD(176);
};

}

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

	Buffer SpheresBuffer;

	double AverageGpuTime;
};

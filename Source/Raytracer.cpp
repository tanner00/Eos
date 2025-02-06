#include "Raytracer.hpp"
#include "CameraController.hpp"
#include "DrawText.hpp"

#include "Luft/Random.hpp"

Raytracer::Raytracer(const Platform::Window* window)
	: Device(window)
	, Graphics(Device.CreateGraphicsContext())
	, FrameIndex(0)
	, AverageGpuTime(0.0)
{
	const auto lerp = [](float a, float b, float t)
	{
		return a + (b - a) * t;
	};

	CreateScreenTextures(window->DrawWidth, window->DrawHeight);

	CreatePipelines();

	DrawText::Get().Init(&Device);

	RandomContext random(0);

	Array<Hlsl::Sphere> spheres(&GlobalAllocator::Get());

	for (int32 a = -10; a < 10; ++a)
	{
		for (int32 b = -10; b < 10; ++b)
		{
			const float materialChoice = random.Float01();
			const Vector position = Vector { static_cast<float>(a) + 0.9f * random.Float01(), 0.2f, static_cast<float>(b) + 0.9f * random.Float01() };

			Hlsl::MaterialType type;
			Float3 albedo = Float3 { 0.0f, 0.0f, 0.0f };
			float refractionIndex = 0.0f;

			if ((position - Vector { +4.0f, +0.2f, +0.0f }).GetMagnitude() > 0.9f)
			{
				if (materialChoice < 0.8f)
				{
					type = Hlsl::MaterialType::Lambertian;
					albedo = { random.Float01(), random.Float01(), random.Float01() };
				}
				else if (materialChoice < 0.95f)
				{
					type = Hlsl::MaterialType::Metallic;
					albedo = { lerp(0.5f, 1.0f, random.Float01()), lerp(0.5f, 1.0f, random.Float01()), lerp(0.5f, 1.0f, random.Float01()) };
				}
				else
				{
					type = Hlsl::MaterialType::Dielectric;
					refractionIndex = 1.5f;
				}

				spheres.Emplace(Float3 { position.X, position.Y, position.Z }, 0.2f, Hlsl::Material { type, albedo, refractionIndex });
			}
		}
	}

	spheres.Emplace(Float3 { 0.0f, -1000.0f, 0.0f }, 1000.0f, Hlsl::Material { Hlsl::MaterialType::Lambertian, Float3 { 0.5f, 0.5f, 0.5f }, 0.0f });

	spheres.Emplace(Float3 { 0.0f, 1.0f, 0.0f }, 1.0f, Hlsl::Material { Hlsl::MaterialType::Dielectric, Float3 { 0.0f, 0.0f, 0.0f }, 1.5f });

	spheres.Emplace(Float3 { -4.0f, 1.0f, 0.0f }, 1.0f, Hlsl::Material { Hlsl::MaterialType::Lambertian, Float3 { 0.4f, 0.2f, 0.1f }, 0.0f });

	spheres.Emplace(Float3 { 4.0f, 1.0f, 0.0f }, 1.0f, Hlsl::Material { Hlsl::MaterialType::Metallic, Float3 { 0.7f, 0.6f, 0.5f }, 0.0f });

	SpheresBuffer = Device.CreateBuffer("Spheres Buffer"_view, spheres.GetData(),
	{
		.Type = BufferType::StructuredBuffer,
		.Usage = BufferUsage::Static,
		.Size = spheres.GetDataSize(),
		.Stride = spheres.GetElementSize(),
	});
}

Raytracer::~Raytracer()
{
	Device.DestroyBuffer(&SpheresBuffer);

	DrawText::Get().Shutdown();

	DestroyPipelines();

	DestroyScreenTextures();
}

void Raytracer::Update(const CameraController& cameraController)
{
	const double gpuTime = Graphics.GetMostRecentGpuTime();
	AverageGpuTime = AverageGpuTime * 0.95 + gpuTime * 0.05;

	char gpuTimeText[20] = {};
	Platform::StringPrint("GPU: %.2f mspf", gpuTimeText, sizeof(gpuTimeText), AverageGpuTime * 1000.0);
	DrawText::Get().Draw(StringView { gpuTimeText, Platform::StringLength(gpuTimeText) }, { 0.0f, 0.0f }, Float3 { 1.0f, 1.0f, 1.0f }, 32.0f);

	if (IsKeyPressedOnce(Key::R))
	{
		Device.WaitForIdle();
		DestroyPipelines();
		CreatePipelines();
	}

	if (cameraController.HasMoved())
	{
		FrameIndex = 0;
	}
	else
	{
		++FrameIndex;
	}

	Graphics.Begin();

	const Texture& frameTexture = SwapChainTextures[Device.GetFrameIndex()];

	Graphics.SetPipeline(&TracePipeline);

	const Vector position = cameraController.GetPosition();
	const Hlsl::TraceRootConstants rootConstants =
	{
		.Orientation = cameraController.GetOrientation(),
		.Position = Float3 { position.X, position.Y, position.Z },
		.FrameIndex = FrameIndex,
		.OutputTextureIndex = Device.Get(OutputTexture),
		.SpheresBufferIndex = Device.Get(SpheresBuffer),
		.SpheresBufferCount = static_cast<uint32>(SpheresBuffer.GetCount()),
	};
	Graphics.SetRootConstants(&rootConstants);

	Graphics.Dispatch((frameTexture.GetWidth() + 7) / 8, (frameTexture.GetHeight() + 7) / 8, 1);

	Graphics.TextureBarrier
	(
		{ BarrierStage::ComputeShading, BarrierStage::Copy },
		{ BarrierAccess::UnorderedAccess, BarrierAccess::CopySource },
		{ BarrierLayout::GraphicsQueueUnorderedAccess, BarrierLayout::GraphicsQueueCopySource },
		OutputTexture
	);
	Graphics.TextureBarrier
	(
		{ BarrierStage::None, BarrierStage::Copy },
		{ BarrierAccess::NoAccess, BarrierAccess::CopyDestination },
		{ BarrierLayout::Undefined, BarrierLayout::GraphicsQueueCopyDestination },
		frameTexture
	);

	Graphics.Copy(frameTexture, OutputTexture);

	Graphics.TextureBarrier
	(
		{ BarrierStage::Copy, BarrierStage::None },
		{ BarrierAccess::CopySource, BarrierAccess::NoAccess },
		{ BarrierLayout::GraphicsQueueCopySource, BarrierLayout::GraphicsQueueUnorderedAccess },
		OutputTexture
	);
	Graphics.TextureBarrier
	(
		{ BarrierStage::Copy, BarrierStage::RenderTarget },
		{ BarrierAccess::CopyDestination, BarrierAccess::RenderTarget },
		{ BarrierLayout::GraphicsQueueCopyDestination, BarrierLayout::RenderTarget },
		frameTexture
	);

	Graphics.SetRenderTarget(frameTexture);
	Graphics.SetViewport(frameTexture.GetWidth(), frameTexture.GetHeight());

	DrawText::Get().Submit(&Graphics, frameTexture.GetWidth(), frameTexture.GetHeight());

	Graphics.TextureBarrier
	(
		{ BarrierStage::RenderTarget, BarrierStage::None },
		{ BarrierAccess::RenderTarget, BarrierAccess::NoAccess },
		{ BarrierLayout::RenderTarget, BarrierLayout::Present },
		frameTexture
	);

	Graphics.End();

	Device.Submit(Graphics);
	Device.Present();
}

void Raytracer::Resize(uint32 width, uint32 height)
{
	Device.WaitForIdle();

	DestroyScreenTextures();
	Device.ReleaseAllDeletes();

	Device.ResizeSwapChain(width, height);
	CreateScreenTextures(width, height);

	Device.WaitForIdle();

	FrameIndex = 0;
}

void Raytracer::CreatePipelines()
{
	Shader traceShader = Device.CreateShader(
	{
		.Stage = ShaderStage::Compute,
		.FilePath = "Shaders/Trace.hlsl"_view,
	});
	TracePipeline = Device.CreatePipeline("Trace Pipeline"_view,
	{
		.Stage = traceShader,
	});
	Device.DestroyShader(&traceShader);
}

void Raytracer::DestroyPipelines()
{
	Device.DestroyPipeline(&TracePipeline);
}

void Raytracer::CreateScreenTextures(uint32 width, uint32 height)
{
	for (usize i = 0; i < FramesInFlight; ++i)
	{
		SwapChainTextures[i] = Device.CreateTexture("SwapChain Render Target"_view, BarrierLayout::Undefined,
		{
			.Width = width,
			.Height = height,
			.Type = TextureType::Rectangle,
			.Format = TextureFormat::Rgba8SrgbUnorm,
			.MipMapCount = 1,
			.RenderTarget = true,
			.Storage = false,
		},
		Device.GetSwapChainResource(i));
	}
	OutputTexture = Device.CreateTexture("Output Texture"_view, BarrierLayout::GraphicsQueueUnorderedAccess,
	{
		.Width = width,
		.Height = height,
		.Type = TextureType::Rectangle,
		.Format = TextureFormat::Rgba8Unorm,
		.MipMapCount = 1,
		.RenderTarget = false,
		.Storage = true,
	});
}

void Raytracer::DestroyScreenTextures()
{
	for (Texture& SwapChainTexture : SwapChainTextures)
	{
		Device.DestroyTexture(&SwapChainTexture);
	}
	Device.DestroyTexture(&OutputTexture);
}

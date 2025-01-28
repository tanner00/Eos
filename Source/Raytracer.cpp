#include "Raytracer.hpp"

#include "DrawText.hpp"

Raytracer::Raytracer(const Platform::Window* window)
	: Device(window)
	, Graphics(Device.CreateGraphicsContext())
	, AverageGpuTime(0.0)
{
	CreateScreenTextures(window->DrawWidth, window->DrawHeight);

	CreatePipelines();

	DrawText::Get().Init(&Device);
}

Raytracer::~Raytracer()
{
	DestroyPipelines();

	DrawText::Get().Shutdown();

	DestroyScreenTextures();
}

void Raytracer::Update()
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

	Graphics.Begin();

	const Texture& frameTexture = SwapChainTextures[Device.GetFrameIndex()];
	Graphics.SetRenderTarget(frameTexture);

	Graphics.SetViewport(frameTexture.GetWidth(), frameTexture.GetHeight());

	Graphics.SetPipeline(&TracePipeline);
	const RootConstants rootConstants =
	{
		.OutputTextureIndex = Device.Get(OutputTexture),
	};
	Graphics.SetRootConstants(&rootConstants);
	Graphics.Dispatch(frameTexture.GetWidth(), frameTexture.GetHeight(), 1);

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

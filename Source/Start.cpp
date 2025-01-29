#include "CameraController.hpp"
#include "Raytracer.hpp"

#include "Luft/Platform.hpp"

static bool NeedsResize = false;

static void ResizeHandler(Platform::Window*)
{
	NeedsResize = true;
}

void Start()
{
	Platform::Window* window = Platform::MakeWindow("Eos", 1280, 720);

	Platform::ShowWindow(window);
	Platform::InstallResizeHandler(ResizeHandler);

	Raytracer raytracer(window);

	static constexpr float fieldOfYRadians = Pi / 2.0f;
	static constexpr float focalLength = 1.0f;
	CameraController cameraController(fieldOfYRadians, focalLength);

	double timeLast = 0.0;

	while (!Platform::IsQuitRequested())
	{
		Platform::ProcessEvents();

		const bool setCaptured = IsMouseButtonPressedOnce(MouseButton::Left);
		const bool setDefault = (IsKeyPressedOnce(Key::Escape) && Platform::GetInputMode() == InputMode::Captured) ||
								!Platform::IsWindowFocused(window);
		const bool quit = IsKeyPressedOnce(Key::Escape) && Platform::GetInputMode() == InputMode::Default;

		if (setCaptured)
		{
			Platform::SetInputMode(window, InputMode::Captured);
		}
		else if (setDefault)
		{
			Platform::SetInputMode(window, InputMode::Default);
		}
		else if (quit)
		{
			break;
		}

		if (window->DrawWidth == 0 || window->DrawHeight == 0)
		{
			continue;
		}

		if (NeedsResize)
		{
			raytracer.Resize(window->DrawWidth, window->DrawHeight);
			NeedsResize = false;
		}

		const double timeNow = Platform::GetTime();
		const double timeDelta = timeNow - timeLast;
		timeLast = timeNow;

		cameraController.Update(static_cast<float>(timeDelta));
		raytracer.Update(cameraController);
	}

	Platform::DestroyWindow(window);
}

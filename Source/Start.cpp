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

	while (!Platform::IsQuitRequested())
	{
		Platform::ProcessEvents();

		if (IsKeyPressedOnce(Key::Escape))
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

		raytracer.Update();
	}

	Platform::DestroyWindow(window);
}

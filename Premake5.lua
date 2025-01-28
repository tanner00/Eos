include "Common.lua"

workspace "Eos"
	DefineConfigurations()
	DefinePlatforms()
	BuildPaths()

	startproject "Eos"

filter { "files:**.hlsl" }
	flags { "ExcludeFromBuild" }
	filter {}

include "Luft/Luft.lua"
include "RHI/RHI.lua"

project "Eos"
	kind "WindowedApp"

	includedirs { "Source", "Luft/Source", "RHI/Source", "RHI/ThirdParty" }
	links { "Luft", "RHI" }

	SetConfigurationSettings()
	UseWindowsSettings()

	files {
		"Source/**.cpp", "Source/**.hpp",
		"Source/**.hlsl",
	}

	filter {}

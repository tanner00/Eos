#pragma once

#include "Luft/Math.hpp"

class CameraController
{
public:
	CameraController();

	void Update(float timeDelta);

	Vector GetPosition() const { return Position; }
	Matrix GetOrientation() const
	{
		return Orientation.ToMatrix();
	}

	uint32 HasMoved() const { return LastMoved == 0; }

private:
	Vector Position;
	Quaternion Orientation;

	float PitchRadians;

	uint32 LastMoved;
	int32 LastMouseX;
	int32 LastMouseY;
};

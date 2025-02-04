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

private:
	Vector Position;
	Quaternion Orientation;

	float PitchRadians;
};

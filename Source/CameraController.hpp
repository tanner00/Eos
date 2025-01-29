#pragma once

#include "Luft/Math.hpp"

class CameraController
{
public:
	explicit CameraController(float fieldOfViewYRadians, float focalLength);

	void Update(float timeDelta);

	Vector GetPosition() const { return Position; }
	Matrix GetOrientation() const
	{
		return Orientation.ToMatrix();
	}

	float GetFieldOfViewYRadians() const { return FieldOfViewYRadians; }
	float GetFocalLength() const { return FocalLength; }

private:
	Vector Position;
	Quaternion Orientation;

	float FieldOfViewYRadians;
	float FocalLength;

	float PitchRadians;
};

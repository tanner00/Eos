#include "CameraController.hpp"

static constexpr float DefaultMovementSpeed = 2.0f;
static constexpr float FastMovementSpeed = 5.0f;

static constexpr float RotationSpeedRadians = 8.0f * DegreesToRadians;

static const Vector DefaultCameraDirection = { +0.0f, +0.0f, -1.0f };

static const Vector InitialCameraPosition = { +13.0f, +2.0f, +3.0f };

CameraController::CameraController()
	: Position(InitialCameraPosition)
	, Orientation(Quaternion::Identity)
	, PitchRadians(0.0f)
	, LastMoved(0)
	, LastMouseX(0)
	, LastMouseY(0)
{
}

void CameraController::Update(float timeDelta)
{
	bool mouseMoved = false;
	if (Platform::GetInputMode() == InputMode::Captured)
	{
		const int32 mouseX = GetMouseX();
		const int32 mouseY = GetMouseY();

		if (LastMouseX != mouseX || LastMouseY != mouseY)
		{
			mouseMoved = true;
		}
		LastMouseX = mouseX;
		LastMouseY = mouseY;

		const float yawDeltaRadians =   -static_cast<float>(mouseX) * RotationSpeedRadians * timeDelta;
		float pitchDeltaRadians =       -static_cast<float>(mouseY) * RotationSpeedRadians * timeDelta;

		PitchRadians += pitchDeltaRadians;
		if (PitchRadians > +Pi / 2.0f)
		{
			pitchDeltaRadians -= (PitchRadians - Pi / 2.0f);
			PitchRadians = +Pi / 2.0f;
		}
		else if (PitchRadians < -Pi / 2.0f)
		{
			pitchDeltaRadians -= (PitchRadians + Pi / 2.0f);
			PitchRadians = -Pi / 2.0f;
		}

		Orientation = Quaternion::AxisAngle(Vector { +0.0f, +1.0f, +0.0f }, yawDeltaRadians) * Orientation;
		Orientation = Orientation.GetNormalized();
		Orientation = Quaternion::AxisAngle(Orientation.Rotate(Vector { +1.0f, +0.0f, +0.0f }), pitchDeltaRadians) * Orientation;
		Orientation = Orientation.GetNormalized();
	}

	const Vector forward = Orientation.Rotate(DefaultCameraDirection);
	const Vector up = Orientation.Rotate(Vector { 0.0f, +1.0f, +0.0f });
	const Vector side = up.Cross(Orientation.Rotate(DefaultCameraDirection));

	Vector movement = Vector::Zero;
	bool moving = false;

	if (IsKeyPressed(Key::W))
	{
		movement = forward;
		moving = true;
	}
	else if (IsKeyPressed(Key::S))
	{
		movement = -forward;
		moving = true;
	}

	if (IsKeyPressed(Key::A))
	{
		movement = movement + side;
		moving = true;
	}
	else if (IsKeyPressed(Key::D))
	{
		movement = movement - side;
		moving = true;
	}

	if (moving)
	{
		const float movementSpeed = IsKeyPressed(Key::Shift) ? FastMovementSpeed : DefaultMovementSpeed;
		Position = Position + movement.GetNormalized() * movementSpeed * timeDelta;
	}

	if (mouseMoved || moving)
	{
		LastMoved = 0;
	}
	else
	{
		++LastMoved;
	}
}

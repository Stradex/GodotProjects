extends "res://src/Scripts/DefaultLevel.gd"

onready var CameraLevel: CameraEntity = $Cameras/CameraLevel;

func use_elevator1(go_up : bool):
	if go_up:
		self.enter_elevator($Teleports/elev1_floor2, CameraLevel, Game.get_local_player().get_camera(), $Cameras/CameraPositions/ElevatorPos1, $Cameras/CameraPositions/ElevatorPos2, 0.25, 4.0, self.map_limit_start, Vector2(self.map_limit_end.x, -250));
	else:
		self.enter_elevator($Teleports/elev1_floor1, CameraLevel, Game.get_local_player().get_camera(), $Cameras/CameraPositions/ElevatorPos2, $Cameras/CameraPositions/ElevatorPos1, 0.25, 4.0);
		self.reset_limits();

extends "res://src/Scripts/DefaultLevel.gd"

var player_inside_storage: bool = false;
var is_night: bool = false;
var CameraPaths: Array;
onready var LevelStaticCamera = $Cameras/LevelCamera1; #Static camera used for camera_move_to

func _ready():
	$Tiles/Clip.visible = false;
	set_day();
	LevelStaticCamera.update_limits(map_limit_start, map_limit_end);
	CameraPaths = $Cameras/CameraPath.get_children();

func _on_player_outside():
	if Game.ActiveCamera:
		Game.ActiveCamera.change_zoom_interpolated(1.5, 0.5);

func _on_player_inside():
	if !player_inside_storage && Game.ActiveCamera:
		Game.ActiveCamera.change_zoom_interpolated(1.0, 0.5);

func select_camera(cameraStr: String):
	var CameraPathNode: NodePath = NodePath(str(self.get_path()) + "/" + cameraStr);
	var CameraNode: Camera2D;
	CameraNode = get_node(CameraPathNode);
	CameraNode.current = true;
	Game.set_active_camera(CameraNode);

func camera_move_to(path_index: int, interpolated: bool = true):
	if Game.ActiveCamera != LevelStaticCamera:
		LevelStaticCamera.global_position = Game.ActiveCamera.global_position;
	LevelStaticCamera.move_to_node2d(CameraPaths[path_index], interpolated);
	Game.set_active_camera(LevelStaticCamera);

func reset_camera(interpolated: bool = false):
	Game.get_local_player().get_camera().move_from_node2d(Game.ActiveCamera, Game.get_local_player().get_camera().Util.init_pos);
	Game.set_active_camera(Game.get_local_player().get_camera());

func show_message(msg: String, time: float) -> void:
	Game.GUI.display_message(msg, time);

#Playing around with the level, don't mind this.

func enter_building():
	Game.ViewportFX.fade_in_out(1.0, 0.5);
	#var tween: Tween = $Tween;
	tween.interpolate_callback(self, 0.75, "entering_building_effect");
	tween.start();

func entering_building_effect():
	is_night = !is_night;
	if is_night:
		set_night();
	else:
		set_day();
	
	player_inside_storage = true;
	$PlayerSpawn.global_position = $Entities/Misc/Teleport1.global_position;
	Game.get_local_player().global_position = $Entities/Misc/Teleport1.global_position;
	#new Camera limits
	map_limit_start.x = 5888;
	map_limit_start.y = -1376;
	map_limit_end.x = 11904;
	map_limit_end.y = 610;
	
	$Tiles/Rain.visible = false;
	Game.ActiveCamera.update_limits(map_limit_start, map_limit_end);
	LevelStaticCamera.update_limits(map_limit_start, map_limit_end);

func set_night():
	$Lights.visible = true;
	$LightOcluders.visible = true;
	$CanvasModulate.color = Color("4e4e4e");
	$Mountains1/CanvasModulate.color = Color("4e4e4e");
	
func set_day():
	$Lights.visible = false;
	$LightOcluders.visible = false;
	$CanvasModulate.color = Color("e6e6e6");
	$Mountains1/CanvasModulate.color = Color("e6e6e6");

func call_elevator(to_floor: int):
	$Tiles/Storage/Elevator.move_to_pos(to_floor);

func players_in_room_1():
	$Entities/Misc/SegmentDoor.enable();
	if !Game.Network.is_client():
		$Tiles/Inside/Floor1/Office4/Door.open(true);

func exit_small_room():
	enter_room($Entities/Misc/Teleport_storagedoor, Game.ActiveCamera, Game.get_local_player().get_camera(), $Entities/Misc/storage_door, Vector2(5888, -1376), Vector2(11904, 610));

func enter_small_room():
	enter_room($Entities/Misc/Teleport_smallroom, Game.ActiveCamera, $Cameras/SmallRoomCamera, $Entities/Misc/smallroom_door, Vector2(8700, 1500), Vector2(10000, 2500));

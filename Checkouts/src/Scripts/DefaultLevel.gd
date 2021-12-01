class_name Level
extends Node2D

var MainMenuScene: PackedScene = preload("res://src/GUI/MainMenu.tscn");
var TransitionsScene: PackedScene = preload("res://src/Transitions/TransitionScene.tscn");
export var map_limit_start: Vector2 = Vector2.ZERO;
export var map_limit_end: Vector2 = Vector2.ZERO;
var already_loaded: bool = false;
var initial_limit_start: Vector2 = Vector2.ZERO;
var initial_limit_end: Vector2 = Vector2.ZERO;

onready var tween: Tween; 

func _enter_tree():
	Game.CurrentMap = self;
	Game.SpawnPoints.clear();
	Game.new_map_loaded();

func _ready():
	
	for p in Game.Players:
		if p:
			Game.spawn_player(p);

	self.already_loaded = true;
	Game.Network.map_is_loaded();
	Game.MainMenu = MainMenuScene.instance();
	Game.MainMenu.set_ingame_mode();
	initial_limit_start = map_limit_start;
	initial_limit_end = map_limit_end;
	tween = Tween.new(); #useful to avoid having to add it manually in each map
	add_child(tween);
	
	var TransitionsInstance: Node = TransitionsScene.instance();
	Game.ViewportFX = TransitionsInstance;
	add_child(TransitionsInstance);
	

func get_world_limits() -> Dictionary:
	var limits: Dictionary = {
		"start": map_limit_start,
		"end": map_limit_end
	};
	return limits;	

func reset_limits(update_camera: bool = true) -> void:
	update_limits(initial_limit_start, initial_limit_end, update_camera);

func update_limits(start: Vector2, end: Vector2, update_camera: bool = true) -> void:
	map_limit_start = start;
	map_limit_end = end;
	if Game.ActiveCamera and update_camera:
		Game.ActiveCamera.update_limits(map_limit_start, map_limit_end);

# SHORT HAND FUNCTIONS (Not great for the programming spirit, But I AM MAKING GAAAAMES)

# ##################################################################################
# enter_elevator info
#
# dest_pos: the node that's going to be the destiny position of our player
# camera_start: the camera entity to start using while the transition
# camera_exit: the camera entity to use after the transition is over
# camera_start_pos: the position where the camera starts
# camera_end_pos: the position where the camera ends
# camera_speed: the speed for the camera movement interpolation
# time: how many time until we can show the player leaving the elevator
# 	(since there's a 2 seconds delay start, time is added 2 seconds always)
# ##################################################################################

func enter_elevator(dest_pos: Node2D, camera_start: CameraEntity, camera_exit: CameraEntity, camera_start_pos: Node2D, camera_end_pos: Node2D, camera_speed: float, time: float, new_limit_start: Vector2 = Vector2.ZERO, new_limit_end: Vector2 = Vector2.ZERO):
		camera_start.global_position = camera_start_pos.global_position;
		Game.set_active_camera(camera_start);
		tween.interpolate_callback(camera_start, 2.0, "move_to_node2d", camera_end_pos, true, camera_speed);
		tween.interpolate_callback(self, time+2.0, "player_leaving_room_fx");
		if new_limit_start.length() > 1.0 and new_limit_end.length() > 1.0: #then limits are not zero
			tween.interpolate_callback(self, time+3.0, "update_limits", new_limit_start,  new_limit_end);
		tween.interpolate_callback(Game, time+3.5, "set_active_camera", camera_exit);
		tween.interpolate_callback(Game.get_local_player(), 3.0, "teleport_to_node", dest_pos);
		player_entering_room_fx();

func enter_room(dest_pos: Node2D, camera_start: CameraEntity, camera_exit: CameraEntity, exit_door: FrontDoor = null, new_limit_start: Vector2 = Vector2.ZERO, new_limit_end: Vector2 = Vector2.ZERO):
	Game.set_active_camera(camera_start);
	if new_limit_start.length() > 1.0 and new_limit_end.length() > 1.0: #then limits are not zero
		tween.interpolate_callback(self, 2.5, "update_limits", new_limit_start,  new_limit_end);
	tween.interpolate_callback(Game, 3.0, "set_active_camera", camera_exit);
	tween.interpolate_callback(Game.get_local_player(), 3.0, "teleport_to_node", dest_pos);
	tween.interpolate_callback(self, 4.0, "player_leaving_room_fx");
	player_entering_room_fx();
	if Game.ViewportFX:
		tween.interpolate_callback(Game.ViewportFX, 2.0, "fade_in_out", 1.0, 1.0);
	if exit_door:
		tween.interpolate_callback(exit_door, 3.5, "open");
		
func player_entering_room_fx():
	Game.get_local_player().freeze();
	Game.get_local_player().disable_collisions();
	tween.interpolate_callback(Game.get_local_player(), 1.0, "fade_out");
	tween.start();

func player_leaving_room_fx():
	Game.get_local_player().fade_in();
	tween.interpolate_callback(Game.get_local_player(), 1.0, "reset_collisions");
	tween.interpolate_callback(Game.get_local_player(), 1.0, "unfreeze");
	tween.start();

#Added just for being able to change maps just from triggers and entities easily
func change_to_map(map_name: String, delay: int = 0.0):
	if Game.Network.is_client():
		if delay > 0.0:
			tween.interpolate_callback(Game, delay, "rpc_id", Game.Network.SERVER_NETID, "change_to_map", map_name);
			tween.start();
		else:
			Game.rpc_id(Game.Network.SERVER_NETID, "change_to_map", map_name);
	else:
		if delay > 0.0:
			tween.interpolate_callback(Game, delay, "change_to_map", map_name);
			tween.start();
		else:
			Game.change_to_map(map_name);

# TO AVOID CRASH IN RELEASE BUILD!
func _exit_tree():
	if Game.CurrentMap == self:
		Game.CurrentMap = null;

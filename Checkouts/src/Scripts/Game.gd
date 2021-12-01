extends Node2D

######################################################################################################################################
# IMPORTANT STUFF FFS: GODOT BUILD RELEASE IS GOING TO CRASH IF AN ENTITY WAS FREED (QUEUE_FREE)
# BUT STILL IS REFERENCED BY SOME ARRAY IN THE SINGLETONS, SO IMPORTANT TO USE _EXIT_FREE TO REMOVE ANY REFERENCE FROM THAT ENTITY
# FROM THE ARRAY'S SINGLETONS OR ANY OTHER REFERENCE...
# THANK YOU GODOT FOR NOT CRASHING IN DEBUG AND NOT EVEN THROWING A WARNING/ERROR FOR THIS, THANK YOU SO MUCH, REALLY.
######################################################################################################################################

const GRAVITY: float = 1200.0
const VERSION: String = "0.1.5"; #Major, Minor, build count
const LANG_FILES_FOLDER: String = "lang";
const CONFIG_FILE: String = "game_config.cfg";
const PLAYER_ATTACK_LAYER: int = 32;
const MAPS_FOLDER: String = "res://src/Levels/";
const START_MAP: String = "DemoLevel.tscn";

var SpawnPoints: Array = [];
var Players: Array = [];
var CurrentMap: Level = null;
var GUI: GUICanvas = null;
var ActiveCamera: Camera2D = null;
var ViewportFX: Node = null; # Reference to the node that leads with transitions. Loaded per level
var MainMenu:Node = null;
var current_lang: String = "";

#Objects (to avoid using classes)
var Boop_Object = preload("res://src/Scripts/Netcode/Boop.gd");
var Util_Object = preload("res://src/Scripts/Util.gd");
var FileSystem: FileSystemBase = load("res://src/Scripts/FileSystem.gd").new();
var Lang = load("res://src/Scripts/Langs.gd").new();
var Config = load("res://src/Scripts/ConfigManager.gd").new();
var Network: NetworkBase = load("res://src/Scripts/Netcode/NetBase.gd").new();
const PlayerNode = preload("res://src/Entities/Player.tscn");
# Game specific vars
var threatLevel: int = 0; # Maybe I want to move this into a different place later.
var players_inventory: Array = [];

#bit mask constants
const BITMASK_PLAYER: int = 1;
const BITMASK_TILES: int = 2;
const BITMASK_STATIC: int = 4;
const BITMASK_ENEMIES: int = 8;
const BITMASK_ENEMYCLIP: int = 16;
const BITMASK_PLAYER_ATTACK: int = 32;
const BITMASK_ENEMY_ATTACK: int = 64;
const BITMASK_PLAYER_BACK: int = 1024; #Used while being behind the map (ELEVATOR EFFECT)
const BITMASK_TILES_BACK: int = 2048; #Used while being behind the map (ELEVATOR EFFECT)
const BITMASK_STATIC_BACK: int = 4096; #Used while being behind the map (ELEVATOR EFFECT)

func _init():
	Lang.load_langs(LANG_FILES_FOLDER);
	Config.load_from_file(CONFIG_FILE);
	current_lang = Lang.get_langs()[0];
	self.call_deferred("update_settings");
	Players.resize(Network.MAX_PLAYERS);
	players_inventory.resize(Network.MAX_PLAYERS);
	for player_inv in players_inventory:
		player_inv = Array();

func clear_players():
	Players.clear();
	Players.resize(Network.MAX_PLAYERS);

func _ready():
	Network.ready();

func _process(_delta):
	self.pause_mode = Node.PAUSE_MODE_PROCESS; #So we can use functions

func set_active_camera(newCamera: CameraEntity):
	if typeof(CurrentMap) != TYPE_NIL:
		newCamera.update_limits(CurrentMap.map_limit_start, CurrentMap.map_limit_end);
	ActiveCamera = newCamera;
	ActiveCamera.current = true;
	print("set camera to: " + str(newCamera));

func print_warning(text: String):
	print("[WARNING] %s" % text);

func get_str(text: String) -> String:
	return Lang.get_str(text, current_lang);

func _input(event):
	if typeof(CurrentMap) == TYPE_NIL || typeof(MainMenu) == TYPE_NIL:
		return;
	
	if event is InputEventKey and Input.is_key_pressed(KEY_ESCAPE) && !event.is_echo():
		if typeof(GUI) != TYPE_NIL && GUI.is_pda_open():
			GUI.hide_pda();
		elif MainMenu.is_inside_tree():
			close_menu();
		else:
			open_menu();

func pause() -> void:
	get_tree().paused = true;
	
func unpause() -> void:
	get_tree().paused = false;

func open_menu() -> void:
	if typeof(CurrentMap) != TYPE_NIL && typeof(MainMenu) != TYPE_NIL:
		CurrentMap.call_deferred("add_child", MainMenu);
	pause();

func close_menu() -> void:
	if typeof(CurrentMap) != TYPE_NIL && typeof(MainMenu) != TYPE_NIL:
		CurrentMap.call_deferred("remove_child", MainMenu);
	unpause();

func change_lang(new_lang: String):
	if Lang.lang_exists(new_lang):
		current_lang = new_lang;
		update_lang_strings();

func update_lang_strings():
	get_tree().call_group("has_lang_strings", "update_lang_strings");
	
func update_settings():
	OS.window_fullscreen = Config.get_value("fullscreen");
	OS.set_window_size(Config.get_value("resolution"));
	change_lang(Config.get_value("language"));

func save_settings():
	Config.save_to_file(CONFIG_FILE);

func get_closest_player_to(node: Node2D) -> Node2D:
	var closestPlayer: Node2D = null;
	var current_dist: float = float(Util_Object.BIG_INT); #Big number
	for Player in Players:
		if !Player:
			continue;
		var test_dist: float = node.global_position.distance_squared_to(Player.global_position);
		if current_dist > test_dist:
			current_dist = test_dist;
			closestPlayer = Player;
	return closestPlayer;

func get_local_player() -> Player:
	return Players[Network.local_player_id]; #fix later

func add_player(netid: int, forceid: int = -1) -> Node2D:
	var free_player_index: int = 0;
	for i in range(Players.size()):
		if Players[i]:
			free_player_index += 1;
			if Players[i].netid == netid: #already exists this player
				print("The player %d with netid %d was already in the list!!" % [i, netid])
				return Players[i];
			continue;
		break;
	
	var player_instance = PlayerNode.instance();
	
	if forceid != -1:
		free_player_index = forceid;

	player_instance.node_id = free_player_index;
	player_instance.netid = netid;
	Players[free_player_index] = player_instance;
	print("Adding player %d with netid %d" % [free_player_index, netid]);
	return Players[free_player_index];

func start_new_game():
	Network.stop_networking();
	change_to_map(START_MAP);

#I hope the remote key does not break anything
remote func change_to_map(map_name: String):
	var full_map_path: String = self.MAPS_FOLDER + map_name;
	CurrentMap = null;
	close_menu();
	MainMenu = null;
	Network.change_map(map_name);
	get_tree().call_deferred("change_scene", full_map_path);

func spawn_player(player: Node2D):
	if player.is_inside_tree():
		print("The player %d was already spawned!!" % player.node_id)
		return;
	player.Spawn = SpawnPoints[0];
	player.position = SpawnPoints[0].position;
	player.z_index = SpawnPoints[0].z_index;
	player.z_as_relative = SpawnPoints[0].z_as_relative;
	player.Spawn.get_parent().call_deferred("add_child", player);

func sanitize_map_name(full_map_path: String) -> String:
	return full_map_path.replacen(MAPS_FOLDER, "");

func get_current_map_path() -> String:
	return sanitize_map_name(CurrentMap.filename);

func get_active_players_count() -> int:
	var p=0;
	for i in range(Players.size()):
		if Players[i]:
			p+=1;
	return p;

func get_active_players() -> Array:
	var result: Array = [];
	for i in range(Players.size()):
		if Players[i]:
			result.append(Players[i]);
	return result;

func new_map_loaded() -> void:
	#clear_players();
	add_player(Network.SERVER_NETID);
	Network.add_clients_to_map();

func current_screen_size() -> Vector2:
	var screenSize: Vector2 = (Game.get_viewport().get_visible_rect().size)*ActiveCamera.zoom;
	return screenSize;

func get_view_rect2(scale: float = 1.0) -> Rect2: #this was fuuun for sure..... :/
	var screenSize: Vector2 = current_screen_size()*scale;
	var startPos: Vector2 = ActiveCamera.global_position-screenSize/2.0;
	var endPos: Vector2 = ActiveCamera.global_position+screenSize/2.0;
	var dif: float;
	if ActiveCamera.limit_left > startPos.x:
		dif = ActiveCamera.limit_left-startPos.x;
		startPos.x += dif;
		endPos.x += dif;
	elif ActiveCamera.limit_right < endPos.x:
		dif = ActiveCamera.limit_right - endPos.x;
		endPos.x += dif;
		startPos.x += dif;
	if ActiveCamera.limit_top > startPos.y:
		dif = ActiveCamera.limit_top-startPos.y;
		startPos.y += dif;
		endPos.y += dif;
	elif ActiveCamera.limit_bottom < endPos.y:
		dif = ActiveCamera.limit_bottom - endPos.y;
		endPos.y += dif;
		startPos.y += dif;
	return Rect2(startPos, screenSize);

func show_pda_message(header: String, msg: String) -> void:
	GUI.show_pda_message(header, msg);

# Netcode specific
remote func game_process_rpc(method_name: String, data: Array): 
	Network.callv(method_name, data);

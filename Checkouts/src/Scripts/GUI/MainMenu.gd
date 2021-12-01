extends CanvasLayer

var resolutions: Array = [
	"640x360",
	"960x540",
	"1280x720",
	"1600x900",
	"1920x1080",
	"2240x1260",
	"2560x1440"
];

var map_list: Array = Array();

onready var ResolutionsOptions: OptionButton = $OptionsContainer/OptionsMenu/VBoxContainer/Resolutions/Resolutions;
onready var MaxPlayerOptions: OptionButton = $OptionsContainer/MultiplayerMenu/VBoxContainer/MaxPlayers/Players;
onready var FullScreenCheckbox: CheckBox = $OptionsContainer/OptionsMenu/VBoxContainer/FullScreen/FullScreenCheckBox;
onready var LangsOptions: OptionButton = $OptionsContainer/OptionsMenu/VBoxContainer/Languages/Langs;
onready var StartServerBtn: Button = $OptionsContainer/MultiplayerMenu/HBoxContainer/StartServer;
onready var JoinButtonBtn: Button = $OptionsContainer/MultiplayerMenu/HBoxContainer2/JoinServer;
onready var SvPlayersCmb: OptionButton = $OptionsContainer/MultiplayerMenu/VBoxContainer/MaxPlayers/Players;
onready var ServerIp: TextEdit = $OptionsContainer/MultiplayerMenu/VBoxContainer2/ServerIP/ServerIP;
onready var MapListOptions: OptionButton = $OptionsContainer/MultiplayerMenu/VBoxContainer/StartMap/Levels;

var options_dialog_shown: bool = false; 

func _ready():
	add_to_group("has_lang_strings");
	
	StartServerBtn.connect("pressed", self, "start_server");
	JoinButtonBtn.connect("pressed", self, "join_server");
	$Buttons/NewGame.connect("pressed", self, "new_game");
	$QuitGame/QuitGame.connect("pressed", self, "quit_game");
	$Buttons/Options.connect("pressed", self, "open_options_dialog");
	$Buttons/Multiplayer.connect("pressed", self, "open_multiplayer_dialog");
	$Buttons/SaveGame.connect("pressed", self, "open_savegame_dialog");
	
	$OptionsContainer/OptionsMenu/HBoxContainer/ApplyChanges.connect("pressed", self, "apply_config_changes");
	
	MaxPlayerOptions.clear();
	for i in range(2, Game.Network.MAX_PLAYERS+1):
		MaxPlayerOptions.add_item(str(i));
	MaxPlayerOptions.select(0);
	
	load_maps();
	load_langs();
	load_resolutions();

	$VersionLabel.text = ("VERSION: %s" % Game.VERSION);
	#unused yet
	$OptionsContainer/OptionsMenu/VBoxContainer/Keys1.visible = false;
	$OptionsContainer/OptionsMenu/VBoxContainer/Keys2.visible = false;
	$OptionsContainer/OptionsMenu/VBoxContainer/Keys3.visible = false;
	$OptionsContainer/OptionsMenu/VBoxContainer/Keys4.visible = false;
	
	update_from_config();
	update_lang_strings();

func load_maps():
	MapListOptions.clear();
	map_list.clear();
	# FIX LATER: by now forcing to ignore the subfolders "Backgrounds" and "ModularScenes"
	map_list = Game.FileSystem.list_files_in_directory(Game.MAPS_FOLDER, ".tscn", "", ["Backgrounds", "ModularScenes"]);
	for map in map_list:
		MapListOptions.add_item(map);
	var start_map_idx: int = map_list.find(Game.START_MAP);
	if start_map_idx != -1:
		MapListOptions.select(start_map_idx);
	else:
		Game.print_warning("Game.START_MAP not found in map lit!");
		MapListOptions.select(0);
	
func update_lang_strings():
	$Buttons/NewGame/ButtonLabel.text = Game.get_str("#str0001");
	$Buttons/Multiplayer/ButtonLabel.text = Game.get_str("#str0010");
	$Buttons/SaveGame/ButtonLabel.text = Game.get_str("#str0003");
	$Buttons/Options/ButtonLabel.text = Game.get_str("#str0004");
	$QuitGame/QuitGame/ButtonLabel.text = Game.get_str("#str0005");
	$OptionsContainer/OptionsMenu/VBoxContainer/FullScreen/Label.text = Game.get_str("#str0006");
	$OptionsContainer/OptionsMenu/VBoxContainer/Resolutions/Label.text = Game.get_str("#str0007");
	$OptionsContainer/OptionsMenu/HBoxContainer/ApplyChanges.text = Game.get_str("#str0008");
	$OptionsContainer/OptionsMenu/VBoxContainer/Languages/Label.text = Game.get_str("#str0009");
	$OptionsContainer/MultiplayerMenu/VBoxContainer/ServerSettings/Label.text = Game.get_str("#str0011");
	$OptionsContainer/MultiplayerMenu/VBoxContainer/MaxPlayers/Label.text = Game.get_str("#str0012");
	$OptionsContainer/MultiplayerMenu/HBoxContainer/StartServer.text = Game.get_str("#str0013");
	$OptionsContainer/MultiplayerMenu/VBoxContainer2/ClientSettings/Label.text = Game.get_str("#str0014");
	$OptionsContainer/MultiplayerMenu/HBoxContainer2/JoinServer.text = Game.get_str("#str0015");

func load_langs():
	LangsOptions.clear();
	var langs: Array = Game.Lang.get_langs();
	for lang in langs:
		LangsOptions.add_item(lang);
	LangsOptions.select(0);

func load_resolutions():
	ResolutionsOptions.clear();
	for res in resolutions:
		ResolutionsOptions.add_item(res);
	ResolutionsOptions.select(0);

func get_string_from_resoltion(res_vec: Vector2) -> String:
	return (str(int(res_vec.x)) + "x" + str(int(res_vec.y)));

func get_resolution_from_string(res_str: String) -> Vector2:
	var str_array: PoolStringArray = res_str.split("x");
	return Vector2(int(str_array[0]),int(str_array[1]));

func quit_game():
	get_tree().quit();

func open_options_dialog():
	#if !options_dialog_shown:
	$AnimationPlayer.play("show_options");
	$OptionsContainer/MultiplayerMenu.hide();
	$OptionsContainer/OptionsMenu.show();
	options_dialog_shown = true;

func open_savegame_dialog():
	if options_dialog_shown:
		$AnimationPlayer.play("hide_options");
		options_dialog_shown = false;
		
func open_multiplayer_dialog():
	#if !options_dialog_shown:
	$AnimationPlayer.play("show_options");
	$OptionsContainer/MultiplayerMenu.show();
	$OptionsContainer/OptionsMenu.hide();
	options_dialog_shown = true;

func new_game():
	Game.start_new_game();

func apply_config_changes():
	Game.Config.set_value("fullscreen", FullScreenCheckbox.pressed);
	Game.Config.set_value("resolution", get_resolution_from_string(resolutions[ResolutionsOptions.selected]));
	Game.Config.set_value("language", LangsOptions.get_item_text(LangsOptions.selected));
	Game.update_settings();
	Game.save_settings();

func start_server():
	var sv_maxPlayers: int = int(SvPlayersCmb.get_item_text(SvPlayersCmb.selected));
	Game.Network.host_server(sv_maxPlayers, MapListOptions.get_item_text(MapListOptions.selected));
func join_server():
	Game.Network.join_server(ServerIp.text);

func set_ingame_mode():
	$BackgroundImage.modulate.a = 0.85;
	$BackgroundImage.modulate.r = 0.0;
	$BackgroundImage.modulate.g = 0.0;
	$BackgroundImage.modulate.b = 0.0;

func update_from_config():
	FullScreenCheckbox.pressed = Game.Config.get_value("fullscreen");
	var resolutionStr: String = get_string_from_resoltion(Game.Config.get_value("resolution"));
	for i in range(resolutions.size()):
		if resolutionStr == resolutions[i]:
			ResolutionsOptions.selected = i;
			break;

	var langs_data: Array = Game.Lang.get_langs();
	for i in range(langs_data.size()):
		if langs_data[i] == Game.Config.get_value("language"):
			LangsOptions.selected = i;
			break;

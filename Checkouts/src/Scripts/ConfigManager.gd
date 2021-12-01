extends Object

var ConfigInfo: ConfigFile = ConfigFile.new();

func load_default():
	ConfigInfo.set_value("config", "resolution", Vector2(1280.0, 720.0));
	ConfigInfo.set_value("config", "language", "english");
	ConfigInfo.set_value("config", "fullscreen", false);

func get_value(key: String):
	return ConfigInfo.get_value("config", key);

func set_value(key: String, value):
	ConfigInfo.set_value("config", key, value);

func load_from_file(file_path: String):
	var err = ConfigInfo.load(file_path);
	if err != OK:
		load_default();
		save_to_file(file_path);

func save_to_file(file_path: String):
	ConfigInfo.save(file_path);

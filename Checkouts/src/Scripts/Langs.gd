extends Object
var langs_data: Dictionary;

func get_str(text: String, lang: String) -> String:
	if (text.begins_with("#str") or text.begins_with("#pda")) && langs_data.has(lang) && langs_data[lang].has(text.replace("#", "")):
		return langs_data[lang][text.replace("#", "")];
	else:
		return text;

func load_langs(folder: String):
	var langs_files: Array = list_files_in_directory(folder, ".json");
	langs_data = {};
	for file in langs_files:
		var lang_name: String = file.get_basename();
		langs_data[lang_name] = get_data_from_json(folder + "/" + file);

func list_files_in_directory(path, extension: String = "") -> Array:
	var files: Array = []
	var dir = Directory.new()
	# Not working in export, I need to fix the problem in engine or wait for update.
	# if !dir.dir_exists(path):
	# 	return [];
	dir.open(path)
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif !file.begins_with(".") && (extension.length() <= 1 || file.ends_with(extension)):
			files.append(file)
	dir.list_dir_end()

	return files


func get_langs() -> Array:
	return langs_data.keys();

func lang_exists(lang_name: String) -> bool:
	return langs_data.has(lang_name);

func get_data_from_json(filename: String) -> Dictionary:
	var file: File = File.new();
	assert(file.file_exists(filename), ("¡The file %s doesn't exists!" % filename));
	file.open(filename, File.READ); #Assumes the file exists
	var text = file.get_as_text();
	var data = parse_json(serialize_for_json(text));
	file.close();
	return data;

#I made this function just because parse_json function does not recognize JSON comments and I don't like that
func serialize_for_json(jsonstr: String) -> String:
	var stringSerialized: String = "";
	var ignore: bool = false;
	var str_length: int = jsonstr.length();
	for i in range(0, str_length):
		if jsonstr[i] == "\n":
			ignore = false;
		elif i < (str_length-1) && jsonstr[i] == '/' && jsonstr[i+1] == "/":
			ignore = true;
		if !ignore:
			stringSerialized+=jsonstr[i];
	return stringSerialized;

class_name FileSystemBase
extends Object

func list_files_in_directory(path, extension: String = "", init_path: String = "", exclude_paths: Array = []) -> Array:
	var files: Array = []
	var dir: Directory = Directory.new()
	# Not working in export, I need to fix the problem in engine or wait for update.
	# if !dir.dir_exists(path):
	# 	return [];
	dir.open(path)
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		if file != "." and file != ".." and dir.current_is_dir():
			if exclude_paths.find(file) != -1:
				continue;
			files+=list_files_in_directory(dir.get_current_dir() + "/" + file, extension, init_path + file + "/");
			#dir.get_current_dir() + "/" + file;
		elif !file.begins_with(".") && (extension.length() <= 1 || file.ends_with(extension)):
			files.append(init_path + file)
	dir.list_dir_end()

	return files

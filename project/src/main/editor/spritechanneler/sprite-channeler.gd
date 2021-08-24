extends Node

onready var textedit_image_list: TextEdit = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/TextEdit
onready var label_image_num: Label = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/LabelNumImages
onready var label_src_path: Label = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer2/LabelSrcPath
onready var label_dst_path: Label = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/LabelDstPath
onready var progress_bar: ProgressBar = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/ProgressBar
onready var button_start: Button = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Button

# without ending slash!
export(String) var path_src = "res://assets/main/world/creature"
export(String) var path_dst = "res://assets/main/world/creature/channels"

var _discovered_images = []
func _ready():
	
	label_src_path.text = path_src
	label_dst_path.text = path_dst
	
	_discovered_images = discover_images()
	textedit_image_list.text = PoolStringArray(_discovered_images).join("\n")
	label_image_num.text = str(_discovered_images.size())
	
func discover_images() -> Array:
	
	var paths_to_search: Array = [""]
	
	var found_images = []
	
	while paths_to_search:
		var path_rel = paths_to_search.pop_front()
		var path_abs = path_src + path_rel + "/"
		
		# don't discover target path itself
		if path_abs == path_dst + "/":
			continue
			
		# open directory and continue on error
		var dir = Directory.new()
		if dir.open(path_abs) != OK:
			printerr("Could not open path " + path_abs)
			continue
			
		# Iteratively scan all directories in path_src
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# add to list of directories to scan (if valid directory)
			if dir.current_is_dir() and file_name != ".." and file_name != ".":
				# don't discover target path itself
				paths_to_search.push_front(path_rel + "/" + file_name)
			# add png files to result list
			elif file_name.ends_with("png"):
				found_images.append(path_rel + "/" + file_name)
			file_name = dir.get_next()
	
	return found_images


func create_image_channels(image_path_rel: String):
	
	var image_path_abs_src: String = path_src + image_path_rel
	var image_path_abs_dst: String = path_dst + image_path_rel
	
	# recursively create directories
	var sub_dirs:Array = image_path_abs_dst.split("/")
	sub_dirs.pop_back() # remove last element, since that's the filename
	var path_to_file_dir = PoolStringArray(sub_dirs).join("/")
	if Directory.new().make_dir_recursive(path_to_file_dir) != OK:
		printerr("Could not create directory " + path_to_file_dir)
	
	# load source image
	var texture:Texture = load(image_path_abs_src)
	var image: Image = texture.get_data()
	
	# prepare some variables
	var colors = ["black", "blue", "green", "red"]
	var sub_images := {}
	var sub_image_empty := {}
	
	# Create one empty Image for each channel
	for c in colors:
		var sub_image: Image = Image.new()
		sub_image.create(image.get_width(), image.get_height(), image.has_mipmaps(), image.get_format())
		sub_image.lock()
		sub_images[c] = sub_image
		sub_image_empty[c] = true

	# Fill Images pixels
	image.lock()
	for y in range(texture.get_height()):
		for x in range(texture.get_width()):
			var color = image.get_pixel(x, y)
			sub_images["red"].set_pixel(x, y, Color(1, 1, 1, color.r * color.a))
			sub_images["green"].set_pixel(x, y, Color(1, 1, 1, color.g * color.a))
			sub_images["blue"].set_pixel(x, y, Color(1, 1, 1, color.b * color.a))
			sub_images["black"].set_pixel(x, y, Color(1, 1, 1, color.a))
			
			for c in colors:
				if sub_images[c].get_pixel(x, y).a > 0:
					sub_image_empty[c] = false
	image.unlock()

	# Create Textures from Images and save them
	for c in colors:
		if sub_image_empty[c]:
			continue
		var sub_texture: ImageTexture = ImageTexture.new()
		sub_texture.create_from_image(sub_images[c])
		
		# "head.png" => "head-red.png"
		var channel_specific_path: String = image_path_abs_dst.replace(".png", "-" + c + ".png")
		
		if ResourceSaver.save(channel_specific_path, sub_texture) != OK:
			printerr("Could not save image to " + channel_specific_path)
	


func _on_Button_pressed():
	progress_bar.min_value = 0
	progress_bar.max_value = _discovered_images.size()
	progress_bar.value = 0
	
	button_start.disabled = true
	
	for image in _discovered_images:
		create_image_channels(image)
		progress_bar.value += 1
		
		# make sure scene doesn't freeze and leave some time to update progress bar
		yield(get_tree(), "idle_frame")
	
	button_start.disabled = false

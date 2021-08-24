extends Node

onready var textedit_image_list: TextEdit = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/TextEdit
onready var label_image_num: Label = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/LabelNumImages
onready var label_src_path: Label = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer2/LabelSrcPath
onready var label_dst_path: Label = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/LabelDstPath
onready var progress_bar: ProgressBar = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/ProgressBar
onready var button_start_all: Button = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer4/ButtonAll
onready var button_start_one: Button = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer4/ButtonOne
onready var preview_container: Control = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Control/HBoxContainer4
onready var preview_result_container: Control = $UI/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Control/HBoxContainer4/Result

# without ending slash!
export(String) var path_src = "res://assets/main/world/creature"
export(String) var path_dst = "res://assets/main/world/creature/channels"

var _discovered_images = []
var _current_progress = 0

func _ready():
	
	label_src_path.text = path_src
	label_dst_path.text = path_dst
	
	_discovered_images = discover_images()
	textedit_image_list.text = PoolStringArray(_discovered_images).join("\n")
	label_image_num.text = str(_discovered_images.size())
	
	progress_bar.min_value = 0
	progress_bar.max_value = _discovered_images.size()
	progress_bar.value = 0
	
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
	
	preview_container.get_child(0).texture = texture
	
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
			
#			var rgba_in: Color = image.get_pixel(x, y)
#			var black_amount: float = max(0.0, 1.0 - rgba_in.r - rgba_in.g - rgba_in.b);
#
#			var rgb_out: Color = Color(0, 0, 0, 1)
#			rgb_out = lerp(rgb_out, Color(1,0,0,1), rgba_in.r / max(0.00001, rgba_in.r + black_amount));
#			rgb_out = lerp(rgb_out, Color(0,1,0,1), rgba_in.g / max(0.00001, rgba_in.g + rgba_in.r + black_amount));
#			rgb_out = lerp(rgb_out, Color(0,0,1,1), rgba_in.b / max(0.00001, rgba_in.b + rgba_in.g + rgba_in.r + black_amount));
#			rgb_out.a = rgba_in.a;
#
#			sub_images["red"].set_pixel(x, y, Color(1, 1, 1, rgb_out.r * rgba_in.a))
#			sub_images["green"].set_pixel(x, y, Color(1, 1, 1, rgb_out.g * rgba_in.a))
#			sub_images["blue"].set_pixel(x, y, Color(1, 1, 1, rgb_out.b * rgba_in.a))
#			sub_images["black"].set_pixel(x, y, Color(1, 1, 1, rgb_out.a * rgba_in.a))
			
			var color = image.get_pixel(x, y)
			
			var black_amount: float = max(0.0, 1.0 - color.r - color.g - color.b);
			
			
			sub_images["red"].set_pixel(x, y, Color(1, 1, 1, color.r * color.a))
			sub_images["green"].set_pixel(x, y, Color(1, 1, 1, color.g * color.a))
			sub_images["blue"].set_pixel(x, y, Color(1, 1, 1, color.b * color.a))
			sub_images["black"].set_pixel(x, y, Color(1, 1, 1, black_amount * color.a))

			for c in colors:
				if sub_images[c].get_pixel(x, y).a > 0:
					sub_image_empty[c] = false
	image.unlock()

	# Create Textures from Images and save them
	var i: int = 0
	for c in colors:
		i += 1
		
		if sub_image_empty[c]:
			preview_container.get_child(i).texture = null
			preview_result_container.get_child(i-1).texture = null
			continue
			
		var sub_texture: ImageTexture = ImageTexture.new()
		sub_texture.create_from_image(sub_images[c])
		sub_texture.flags = 0
		
		# "head.png" => "head-red.png"
		var channel_specific_path: String = image_path_abs_dst.replace(".png", "-" + c + ".png")
		
		if ResourceSaver.save(channel_specific_path, sub_texture) != OK:
			printerr("Could not save image to " + channel_specific_path)
		else:
			var channel = load(channel_specific_path)
			preview_container.get_child(i).texture = channel
			preview_result_container.get_child(i-1).texture = channel


func _on_ButtonAll_pressed():
	button_start_all.disabled = true
	button_start_one.disabled = true
	
	for image_id in range(_current_progress, _discovered_images.size()):
		# create image channels
		var image: String = _discovered_images[image_id]
		create_image_channels(image)
		
		# update state and progress bar
		_current_progress += 1
		progress_bar.value = _current_progress
		
		# make sure scene doesn't freeze and leave some time to update progress bar
		yield(get_tree(), "idle_frame")

func _on_ButtonOne_pressed():
	
	button_start_all.disabled = true
	button_start_one.disabled = true
	
	# create image channels
	var image: String = _discovered_images[_current_progress]
	create_image_channels(image)
	
	# update state and progress bar
	_current_progress += 1
	progress_bar.value = _current_progress
	
	if _current_progress < _discovered_images.size():
		button_start_all.disabled = false
		button_start_one.disabled = false

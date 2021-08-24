tool
class_name ChanneledPackedSprite
extends PackedSprite

"""

"""

var _reset_channel_colors: Array = [Color.black, Color.black, Color.black, Color.black]
var _reset_sub_textures: Array = [null, null, null, null]

const _id_to_color: Array = ["red", "green", "blue", "black"]
const _color_to_id: Dictionary = {"red":0, "green":1, "blue":2, "black":3}

const _color_id_draw_order = [3, 2, 1, 0]

export(Array) var sub_textures := _reset_sub_textures
export(Array) var channel_colors = _reset_channel_colors

func set_texture(new_texture: Texture) -> void:
	if texture != new_texture:
		.set_texture(new_texture)
		_reload_sub_textures()

func reset() -> void:
	sub_textures = _reset_sub_textures
	reset_channel_colors()
	
# one or multiple can be null
func set_channel_colors(red, green, blue, black) -> void:
	if red:
		channel_colors[0] = red
	if green:
		channel_colors[1] = green
	if blue:
		channel_colors[2] = blue
	if black:
		channel_colors[3] = black
	update()
	
func set_channel_color(color_name: String, color: Color) -> void:
	for other_color_name in _color_to_id.keys():
		if other_color_name == color_name:
			channel_colors[_color_to_id[other_color_name]] = color
	update()
	
func reset_channel_colors() -> void:
	channel_colors = _reset_channel_colors
	update()

func _reload_sub_textures():
	if not texture:
		return
	
	sub_textures = _reset_sub_textures
	
	var texture_path_original: String = texture.resource_path
	for c in range(4):
		# TODO this is not exactly best practice
		# maybe creating a custom Resource type would be the way to go
		# also, this is syncronously loaded
		var texture_path: String = texture_path_original.replace("res://assets/main/world/creature", "res://assets/main/world/creature/channels")
		texture_path = texture_path.replace(".png", "-" + _id_to_color[c] + ".png")
		
		# only set this when file actually exists i.e. channel used
		if Directory.new().file_exists(texture_path):
			sub_textures[c] = load(texture_path)

func _on_draw() -> void:
	if not _frame_dest_rects:
		# frame data not loaded
		return
	
	var rect: Rect2 = _frame_dest_rects[min(frame, _frame_dest_rects.size() - 1)]
	rect.position += offset
	if centered:
		rect.position -= rect_size * 0.5
	if frame < 0 or frame >= _frame_src_rects.size():
		push_warning("Frame data '%s' does not define a frame #%s" % [frame_data, frame])
	else:
		# draw all channels that exist in correct order
		for c in _color_id_draw_order:
			var sub_texture = sub_textures[c]
			if sub_texture:
				draw_texture_rect_region(sub_texture, rect, _frame_src_rects[frame], channel_colors[c])


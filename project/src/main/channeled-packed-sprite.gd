tool
class_name ChanneledPackedSprite
extends PackedSprite

"""

"""

export var sub_textures := {}

# Order is important, as it defines the draw order (black must be first)!
var _color_list = ["black", "blue", "green", "red"]
export(Dictionary) var colors = {
	"black": Color.black,
	"blue": Color.black,
	"green": Color.black,
	"red": Color.black
}

func set_texture(new_texture: Texture) -> void:
	if texture != new_texture:
		.set_texture(new_texture)
		_reload_sub_textures()

func reset():
	sub_textures = {}
	colors = {
		"black": Color.black,
		"blue": Color.black,
		"green": Color.black,
		"red": Color.black
	}
	update()

func _reload_sub_textures():
	if not texture:
		return
	
	sub_textures = {}
	var texture_path_original: String = texture.resource_path
	for c in _color_list:
		var texture_path: String = texture_path_original.replace("res://assets/main/world/creature", "res://assets/main/world/creature/channels")
		texture_path = texture_path.replace(".png", "-" + c + ".png")
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
	elif sub_textures:
		for c in _color_list:
			if sub_textures.has(c):
				draw_texture_rect_region(sub_textures[c], rect, _frame_src_rects[frame], colors[c])


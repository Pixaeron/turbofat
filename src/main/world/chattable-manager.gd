extends Node
"""
Tracks Spira's location and the location of all chattables. Handles questions like 'which chattable is focused' and
'which chattables are nearby'.
"""

# emitted when focus changes to a new object, or when all objects are unfocused.
signal focus_changed

# Maximum range for Spira to successfully interact with an object
const MAX_INTERACT_DISTANCE := 50.0

# Chat appearance for different characters
var _chat_theme_defs := {
	"Spira": {"accent_scale":0.66,"accent_swapped":true,"accent_texture":13,"color":"b23823"}
}

# The player's sprite
var _spira: Spira setget set_spira

# The currently focused object
var _focused: Spatial setget ,get_focused

# 'false' if the player is temporarily disallowed from interacting with nearby objects, such as while chatting
var _focus_enabled := true setget set_focus_enabled, is_focus_enabled

func _physics_process(_delta: float) -> void:
	var min_distance := MAX_INTERACT_DISTANCE
	var new_focus: Spatial

	if _focus_enabled and _spira:
		# iterate over all chattables and find the nearest one
		for chattable_obj in get_tree().get_nodes_in_group("chattables"):
			if not is_instance_valid(chattable_obj):
				continue
			var chattable: Spatial = chattable_obj
			var distance := chattable.global_transform.origin.distance_to(_spira.global_transform.origin)
			if distance <= min_distance:
				min_distance = distance
				new_focus = chattable
	
	if new_focus != _focused:
		_focused = new_focus
		emit_signal("focus_changed")


"""
Purges all node instances from the manager.

Because ChattableManager is a singleton, node instances must be purged before changing scenes. Otherwise it's
possible for an invisible object from a previous scene to receive focus.
"""
func clear() -> void:
	_spira = null
	_focused = null


func set_spira(spira: Spira) -> void:
	_spira = spira


"""
Returns the overworld object which the player will currently interact with if they hit the button.
"""
func get_focused() -> Spatial:
	return _focused


"""
Returns 'true' if the player will currently interact with the specified object if they hit the button.
"""
func is_focused(chattable: Spatial) -> bool:
	return chattable == _focused


"""
Globally enables/disables focus for nearby objects.

Regardless of whether or not the focused object changed, this notifies all listeners with a 'focus_changed' event.
This is because some UI elements render themselves differently during chats when the player can't interact with
anything.
"""
func set_focus_enabled(focus_enabled: bool) -> void:
	_focus_enabled = focus_enabled
	
	if not _focus_enabled:
		_focused = null
		# when focus is globally disabled, chat icons vanish. emit a signal to notify listeners
		emit_signal("focus_changed")


"""
Returns 'true' if focus is globally enabled/disabled for all objects.
"""
func is_focus_enabled() -> bool:
	return _focus_enabled


"""
Returns the overworld object which has the specified 'chat name'.

During dialog sequences, we sometimes need to know which overworld object corresponds to the person saying the current
dialog line. This function facilitates that.
"""
func get_chatter(chat_name: String) -> Spatial:
	var chatter: Spatial
	if chat_name == "Spira":
		chatter = _spira
	else:
		for chattable_obj in get_tree().get_nodes_in_group("chattables"):
			var chattable: Spatial = chattable_obj
			if chattable.has_meta("chat_name") and chattable.get_meta("chat_name") == chat_name:
				chatter = chattable
				break
	return chatter


"""
Returns the accent definition for the overworld object which has the specified 'chat name'.
"""
func get_chat_theme_def(chat_name: String) -> Dictionary:
	if chat_name and not _chat_theme_defs.has(chat_name):
		# refresh our cache of accent definitions
		for chattable in get_tree().get_nodes_in_group("chattables"):
			if chattable.has_meta("chat_name") and chattable.has_meta("chat_theme_def"):
				add_chat_theme_def(chattable.get_meta("chat_name"), chattable.get_meta("chat_theme_def"))
	
		if not _chat_theme_defs.has(chat_name):
			# report a warning and store a stub definition to prevent repeated errors
			_chat_theme_defs[chat_name] = {}
			push_error("Missing chat_theme_def for chattable '%s'" % chat_name)
	
	return _chat_theme_defs.get(chat_name, {})


func add_chat_theme_def(chat_name: String, chat_theme_def: Dictionary) -> void:
	_chat_theme_defs[chat_name] = chat_theme_def

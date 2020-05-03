class_name OverworldUi
extends Control
"""
Overlays 2D UI elements over the 3D world.

This includes chats, buttons and debug messages.
"""

signal chat_started

signal chat_ended

# signal emitted when we present the player with a dialog choice
signal showed_chat_choices

var turbo: Turbo

# Characters we're currently chatting with. We try to keep them all in frame and facing Turbo.
var chatters := []

var _show_fps := false setget set_show_fps, is_show_fps
var _show_version := true setget set_show_version, is_show_version
var _chat_library := ChatLibrary.new()

# These two fields store details for the upcoming scenario. We store the scenario details during the dialog sequence
# and launch the scenario when the dialog window closes.
var _launched_scenario: ScenarioSettings
var _scenario_customer_def: Dictionary

func _ready() -> void:
	_update_visible()


func _input(event: InputEvent) -> void:
	if not chatters and event.is_action_pressed("interact") and InteractableManager.get_focused():
		get_tree().set_input_as_handled()
		start_chat()


func start_chat() -> void:
	var chat_tree := _chat_library.load_chat_events()
	
	chatters = [InteractableManager.get_focused()]
	_update_visible()
	InteractableManager.set_focus_enabled(false)
	make_chatters_face_eachother()
	$ChatUi.play_chat_tree(chat_tree)
	emit_signal("chat_started")


func set_show_fps(show_fps: bool) -> void:
	_show_fps = show_fps
	_update_visible()


func is_show_fps() -> bool:
	return _show_fps


func set_show_version(show_version: bool) -> void:
	_show_version = show_version
	_update_visible()


func is_show_version() -> bool:
	return _show_version


"""
Turn the the active chat participants towards each other, and make them face the camera.
"""
func make_chatters_face_eachother() -> void:
	# make turbo face the other characters
	if chatters.size() >= 1:
		turbo.orient_toward(chatters[0])
	
	# make the other characters face turbo
	for chatter in chatters:
		if chatter.has_method("orient_toward"):
			chatter.orient_toward(turbo)


"""
Updates the different UI components to be visible/invisible based on the UI's current state.
"""
func _update_visible() -> void:
	$ChatUi.visible = true if chatters else false
	$FpsLabel.visible = _show_fps and not chatters
	$VersionLabel.visible = _show_version and not chatters


func _on_PuzzleButton_pressed() -> void:
	InteractableManager.clear()
	get_tree().change_scene("res://src/main/ui/ScenarioMenu.tscn")


func _on_ChatUi_pop_out_completed() -> void:
	# unset mood
	for chatter in chatters:
		if chatter and chatter.has_method("play_mood"):
			chatter.call("play_mood", ChatEvent.Mood.DEFAULT)
	
	chatters = []
	InteractableManager.set_focus_enabled(true)
	_update_visible()
	emit_signal("chat_ended")
	
	if _launched_scenario:
		InteractableManager.clear()
		ScenarioLibrary.change_scenario_scene(_launched_scenario, true, _scenario_customer_def)


func _on_ChatUi_chat_event_played(chat_event: ChatEvent) -> void:
	make_chatters_face_eachother()
	
	# update the chatter's mood
	var chatter := InteractableManager.get_chatter(chat_event.who)
	if chatter and chatter.has_method("play_mood"):
		chatter.call("play_mood", chat_event.mood)
	if chat_event.meta:
		var meta: Array = chat_event.meta
		if meta.has("scenario"):
			_launched_scenario = ScenarioLibrary.load_scenario_from_file("boatricia")
			if chatters[0].has_method("get_customer_def"):
				_scenario_customer_def = chatters[0].get_customer_def()


func _on_ChatUi_showed_choices() -> void:
	emit_signal("showed_chat_choices")
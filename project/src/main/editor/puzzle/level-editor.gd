class_name LevelEditor
extends Control
"""
A graphical level editor which lets players create, load and save levels.

Full instructions are available at https://github.com/Poobslag/turbofat/wiki/level-editor
"""

# default to an empty level; players may be confused if it's not empty
const DEFAULT_LEVEL := "practice/ultra_normal"

export (PackedScene) var PuzzleScene: PackedScene

# level scene currently being tested
var _test_scene: Node

onready var level_name := $HBoxContainer/SideButtons/LevelName
onready var _level_json := $HBoxContainer/SideButtons/Json

func _ready() -> void:
	var level_text := FileUtils.get_file_as_text(LevelSettings.path_from_level_key(DEFAULT_LEVEL))
	_level_json.text = level_text
	_level_json.refresh_tile_map()
	level_name.text = DEFAULT_LEVEL
	Breadcrumb.connect("trail_popped", self, "_on_Breadcrumb_trail_popped")


func save_level(path: String) -> void:
	FileUtils.write_file(path, _level_json.text)


func load_level(path: String) -> void:
	var level_text := FileUtils.get_file_as_text(path)
	_level_json.text = level_text
	_level_json.refresh_tile_map()
	
	var new_level_name := path.get_file()
	new_level_name = new_level_name.trim_suffix(".json")
	new_level_name = StringUtils.hyphens_to_underscores(new_level_name)
	level_name.text = new_level_name


func _start_test() -> void:
	var settings := LevelSettings.new()
	settings.load_from_text(level_name.text, _level_json.text)
	CurrentLevel.start_level(settings)
	_test_scene = PuzzleScene.instance()
	
	# back button should close level; shouldn't redirect us to a new scene
	SceneTransition.push_trail("res://src/main/editor/puzzle/LevelEditor.tscn::test", true)
	add_child(_test_scene)
	
	# hide the level controls while testing a level, otherwise hitting 'esc' will do two things
	$HBoxContainer.visible = false


func _stop_test() -> void:
	if _test_scene:
		_test_scene.queue_free()
		_test_scene = null
		MusicPlayer.stop()
		
		# re-enable the level controls which was disabled while testing the level
		$HBoxContainer.visible = true


func _on_Test_pressed() -> void:
	_stop_test()
	_start_test()


func _on_Breadcrumb_trail_popped(prev_path: String) -> void:
	if prev_path == "res://src/main/editor/puzzle/LevelEditor.tscn::test":
		# player exited the level under test; stop the test
		_stop_test()


func _on_Quit_pressed() -> void:
	var skip_transition := false
	if Breadcrumb.trail.back() == "res://src/main/editor/puzzle/LevelEditor.tscn::test":
		# player exited the level under test; no scene transition
		skip_transition = true
	SceneTransition.pop_trail(skip_transition)

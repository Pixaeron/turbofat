extends Control
"""
Menu which lists a set of scenarios which the player can play over and over and try to beat their high scores.
"""

const BEGINNER_TUTORIAL_SCENARIO := "tutorial-beginner-0"

# Rank required to unlock harder levels. Rank 24 is an S-
const RANK_TO_UNLOCK := 24.0

func _ready() -> void:
	var unlock_message: String = "(%s to unlock)" % Global.grade(RANK_TO_UNLOCK)
	if not PlayerData.scenario_history.has(BEGINNER_TUTORIAL_SCENARIO):
		launch_scenario(BEGINNER_TUTORIAL_SCENARIO)
	if PlayerData.get_best_scenario_rank("sprint-normal") > RANK_TO_UNLOCK:
		$VBoxContainer/Sprint/Expert.disable(unlock_message)
	if PlayerData.get_best_scenario_rank("ultra-normal", "seconds") > RANK_TO_UNLOCK:
		$VBoxContainer/Ultra/Hard.disable(unlock_message)
	if PlayerData.get_best_scenario_rank("ultra-hard", "seconds") > RANK_TO_UNLOCK:
		$VBoxContainer/Ultra/Expert.disable(unlock_message)
	if PlayerData.get_best_scenario_rank("marathon-normal") > RANK_TO_UNLOCK:
		$VBoxContainer/Marathon/Hard.disable(unlock_message)
	if PlayerData.get_best_scenario_rank("marathon-hard") > RANK_TO_UNLOCK:
		$VBoxContainer/Marathon/Expert.disable(unlock_message)
	if PlayerData.get_best_scenario_rank("marathon-expert") > RANK_TO_UNLOCK:
		$VBoxContainer/Marathon/Master.disable(unlock_message)
	if OS.has_feature("web"):
		$OverworldButton.visible = false
	
	# grab focus so the player can navigate with the keyboard
	$VBoxContainer/Marathon/Normal/Button.grab_focus()


func launch_scenario(scenario_name: String) -> void:
	var scenario_settings := ScenarioLibrary.load_scenario_from_name(scenario_name)
	ScenarioLibrary.change_scenario_scene(scenario_settings, false)


func _on_OverworldButton_pressed() -> void:
	get_tree().change_scene("res://src/main/world/Overworld.tscn")


func _on_ScenarioButton_chose_scenario(scenario_name: String) -> void:
	launch_scenario(scenario_name)


func _on_LevelEditorButton_pressed() -> void:
	get_tree().change_scene("res://src/main/puzzle/editor/LevelEditor.tscn")


func _on_TutorialButton_pressed() -> void:
	launch_scenario(BEGINNER_TUTORIAL_SCENARIO)

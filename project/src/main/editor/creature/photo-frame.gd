extends Control

export (NodePath) var creature_path: NodePath

onready var _creature: Creature = get_node(creature_path)

func _ready() -> void:
	$Panel/ViewportContainer/Viewport.world_2d = _creature.get_node("CreatureOutline/Viewport").world_2d
	_creature.creature_visuals.connect("head_moved", self, "_on_CreatureVisuals_head_moved")


func _on_CreatureVisuals_head_moved() -> void:
	$Panel/ViewportContainer/Viewport/Camera2D.position = Vector2(512, 820) + _creature.creature_visuals.get_node("Neck0").position

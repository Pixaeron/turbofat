extends Control

export (NodePath) var creature_path: NodePath

onready var _creature: Creature = get_node(creature_path)

func _ready() -> void:
	$Viewport.world = _creature.get_node("CreatureOutline/Viewport").world

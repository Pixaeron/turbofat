extends Node2D
"""
Manages shadows for all creatures in a scene.
"""

export (PackedScene) var CreatureShadowScene: PackedScene

func _ready() -> void:
	# create shadows for all creatures in the scene
	for creature_node in get_tree().get_nodes_in_group("creatures"):
		var creature: Creature = creature_node
		var creature_shadow: CreatureShadow = CreatureShadowScene.instance()
		creature_shadow.shadow_scale = creature.scale * Creature.TEXTURE_SCALE
		add_child(creature_shadow)
		creature_shadow.creature_path = creature_shadow.get_path_to(creature)

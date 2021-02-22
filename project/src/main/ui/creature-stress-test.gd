extends Node

const DEFAULT_CREATURE_COUNT := 6
const CREATURE_IDS := [
	"alexander", "beats", "dingold", "goris", "logana", "pipedro",
	"rhinosaur", "snorz", "squawkapus", "stunker", "terpion", "vile",
]

export (PackedScene) var CreaturePackedScene: PackedScene

func _ready() -> void:
	PlayerData.creature_library.forced_fatness = 1.0
	_add_creatures(DEFAULT_CREATURE_COUNT)


func _add_creatures(count: int) -> void:
	for i in range(0, count):
		var creature: Creature = CreaturePackedScene.instance()
		
		var creature_index := get_tree().get_nodes_in_group("creatures").size()
		creature.creature_id = CREATURE_IDS[creature_index % CREATURE_IDS.size()]
		
		var target_rect := Rect2(0, 0, 1024, 768).grow(-50)
		creature.position = Vector2(rand_range(target_rect.position.x, target_rect.end.x), rand_range(target_rect.position.y, target_rect.end.y))
		
		$Creatures.add_child(creature)


func _on_CreatureButton_pressed(creature_delta: int):
	if creature_delta > 0:
		print("31: Let's add %s creatures!" % [creature_delta])
	elif creature_delta < 0:
		print("33: Let's remove %s creatures!" % [-creature_delta])

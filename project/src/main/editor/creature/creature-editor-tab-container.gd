extends TabContainer

func _ready() -> void:
	_refresh_visible()


func _refresh_visible() -> void:
	var changed_to_photo_tab := get_tab_title(current_tab) == "Photo"
	
	for node in get_tree().get_nodes_in_group("only_visible_with_photo_tab"):
		node.visible = changed_to_photo_tab
	
	for node in get_tree().get_nodes_in_group("not_visible_with_photo_tab"):
		node.visible = not changed_to_photo_tab


func _on_tab_changed(tab: int) -> void:
	_refresh_visible()

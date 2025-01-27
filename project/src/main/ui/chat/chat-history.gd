class_name ChatHistory
"""
Stores a history of conversations the player's had.

Keeps track of which conversations the player's had and how long ago they've had them.
"""

"""
Constant for the age of conversations we've never had. This is a large number so that evaluating 'have we had this
conversation recently?' will work without requiring a third branch to handle the case where we haven't had a
conversation before.
"""
const CHAT_AGE_NEVER := 99999999

"""
Tracks which conversations the player has had with each creature. The value is a per-creature index which starts from
0 and increments with each conversation with that creature.

key: chat key
value: ordering of when the chat happened (smaller is older)
"""
var chat_history: Dictionary

"""
Tracks the number of conversations the player has had with each creature.

key: chat key fragment
value: int corresponding to number of chats with a character
"""
var chat_counts: Dictionary

"""
Tracks the number of consecutive filler chats for each creature. After a creature has enough filler chats, they'll
have a more serious or interesting conversation.

key: creature id
value: number of consecutive filler chats
"""
var filler_counts: Dictionary

func reset() -> void:
	chat_history.clear()
	chat_counts.clear()
	filler_counts.clear()


func increment_filler_count(creature_name: String) -> void:
	filler_counts[creature_name] = get_filler_count(creature_name) + 1


func reset_filler_count(creature_name: String) -> void:
	filler_counts[creature_name] = 0


func get_filler_count(creature_name: String) -> int:
	# explicitly cast to an int to avoid warnings. numbers are loaded from json as floats
	return filler_counts.get(creature_name, 0) as int


func add_history_item(history_key: String) -> void:
	var chat_prefix := StringUtils.substring_before_last(history_key, "/")
	
	if not chat_counts.has(chat_prefix):
		chat_counts[chat_prefix] = 0
	var chat_count: int = chat_counts[chat_prefix]
	chat_counts[chat_prefix] += 1
	
	chat_history[history_key] = chat_count


func delete_history_item(history_key: String) -> void:
	chat_history.erase(history_key)


"""
Returns how long ago the player had the specified chat.

Used to avoid repeating conversations too frequently.
"""
func get_chat_age(history_key: String) -> int:
	# We subtract the index assigned to the chat history from the total number
	# of chats for that creature to calculate the entry's age.
	var chat_prefix := StringUtils.substring_before_last(history_key, "/")
	var chat_count: int = chat_counts.get(chat_prefix, 0)
	var result := CHAT_AGE_NEVER
	if chat_count > 0 and chat_history.has(history_key):
		result = chat_count - chat_history.get(history_key) - 1
	return result


func is_chat_finished(history_key: String) -> bool:
	return chat_history.has(history_key)


func to_json_dict() -> Dictionary:
	return {
		"history_items": chat_history,
		"counts": chat_counts,
		"filler_counts": filler_counts,
	}


func from_json_dict(json: Dictionary) -> void:
	chat_history = json.get("history_items", {})
	_convert_float_values_to_ints(chat_history)
	
	chat_counts = json.get("counts", {})
	_convert_float_values_to_ints(chat_counts)
	
	filler_counts = json.get("filler_counts", {})
	_convert_float_values_to_ints(filler_counts)


"""
Converts the float values in a Dictionary to int values.

Godot's JSON parser converts all ints into floats, so we need to change them back. See Godot #9499
https://github.com/godotengine/godot/issues/9499
"""
func _convert_float_values_to_ints(dict: Dictionary) -> void:
	for key in dict:
		if dict[key] is float:
			dict[key] = int(dict[key])


"""
Converts a path like 'res://assets/main/creatures/primary/bones/filler-001.chat' into a history key like
'chat/bones/filler_001'.

Using these clean short history keys has many benefits. Most notably they aren't invalidated if we move files or
change extensions.
"""
static func history_key_from_path(path: String) -> String:
	var history_key := path
	history_key = history_key.trim_suffix(".chat")
	history_key = history_key.trim_prefix("res://assets/main/")
	if history_key.begins_with("creatures/primary/"):
		history_key = "creature/" + history_key.trim_prefix("creatures/primary/")
	elif history_key.begins_with("puzzle/levels/cutscenes"):
		history_key = "level/" + history_key.trim_prefix("puzzle/levels/cutscenes/")
	history_key = StringUtils.hyphens_to_underscores(history_key)
	return history_key


"""
Converts a history key like 'creature/bones/filler_001' into a path like
'res://assets/main/creatures/primary/bones/filler-001.chat'
"""
static func path_from_history_key(history_key: String) -> String:
	var path := history_key
	path = StringUtils.underscores_to_hyphens(history_key)
	if history_key.begins_with("creature/"):
		path = path.replace("creature/", "creatures/primary/")
	elif history_key.begins_with("level/"):
		path = path.replace("level/", "puzzle/levels/cutscenes/")
	path = "res://assets/main/%s.chat" % [path]
	return path

class_name Playfield
extends Control
"""
Stores information about the game playfield: writing pieces to the playfield, calculating whether a line was cleared or whether
a box was made, pausing and playing sound effects
"""

# signal emitted when a line is cleared
signal line_cleared

# signal emitted when the customer should leave
signal customer_left

# playfield dimensions. the playfield extends a few rows higher than what the player can see
const ROW_COUNT = 20
const COL_COUNT = 9

# bonus points which are awarded as the player continues a combo
const COMBO_SCORE_ARR = [0, 0, 5, 5, 10, 10, 15, 15, 20]

# player's current combo
var combo := 0
# 'true' if the player is currently playing, and the time spent should count towards their stats
var clock_running := false

# lines which are currently being cleared
var _cleared_lines := []
# total frames to wait when clearing a line/making a box
var _line_clear_delay := 0
# remaining frames to wait for clearing the current lines
var _remaining_line_clear_frames := 0
# remaining frames to wait for making the current box
var _remaining_box_build_frames := 0
# 'true' if the 'line fall sound' should play after the current lines are cleared. The sound doesn't play if nothing
# drops.
var _should_play_line_fall_sound := false
# The number of pieces the player has dropped without clearing a line or making a box, plus one.
var _combo_break := 0

onready var _score = $"../Score"

# sounds which play as the player continues a combo
onready var _combo_sound_arr := [$Combo1Sound, $Combo1Sound, $Combo2Sound, $Combo3Sound, $Combo4Sound, $Combo5Sound,
		$Combo6Sound, $Combo7Sound, $Combo8Sound, $Combo9Sound, $Combo10Sound, $Combo11Sound, $Combo12Sound,
		$Combo13Sound, $Combo14Sound, $Combo15Sound, $Combo16Sound, $Combo17Sound, $Combo18Sound, $Combo19Sound,
		$Combo20Sound, $Combo21Sound, $Combo22Sound, $Combo23Sound, $Combo24Sound]

onready var _combo_sound_endless_arr := [$ComboEndless00Sound, $ComboEndless01Sound, $ComboEndless02Sound, 
		$ComboEndless03Sound, $ComboEndless04Sound, $ComboEndless05Sound, $ComboEndless06Sound, $ComboEndless07Sound,
		$ComboEndless08Sound, $ComboEndless09Sound, $ComboEndless10Sound, $ComboEndless11Sound]

func _ready() -> void:
	$TileMapClip/TileMap.clear()
	$TileMapClip/TileMap/CornerMap.clear()


func _physics_process(delta: float) -> void:
	if clock_running:
		Global.scenario_performance.seconds += delta
	
	if _line_clear_delay > 0:
		if _remaining_box_build_frames > 0:
			_remaining_box_build_frames -= 1
			if _remaining_box_build_frames <= 0:
				if _check_for_line_clear():
					_remaining_line_clear_frames = _line_clear_delay
				else:
					_line_clear_delay = 0
		elif _remaining_line_clear_frames > 0:
			_remaining_line_clear_frames -= 1
			if _remaining_line_clear_frames <= 0:
				_line_clear_delay = 0
				if not _cleared_lines.empty():
					_delete_rows()


"""
Returns true if the Playfield is ready for a new piece to drop; false if it's paused for some kind of animation or delay.
"""
func ready_for_new_piece() -> bool:
	return _remaining_line_clear_frames <= 0 and _remaining_box_build_frames <= 0


"""
Clears the playfield and resets everything for a new game.
"""
func start_game() -> void:
	Global.scenario_performance = ScenarioPerformance.new()
	$TileMapClip/TileMap.clear()
	$TileMapClip/TileMap/CornerMap.clear()


"""
Writes a piece to the playfield, checking whether it makes any boxes or clears any lines.

Returns true if the newly written piece results in a pause of some sort.
"""
func write_piece(pos: Vector2, orientation: int, type, new_line_clear_frames: int, death_piece := false) -> bool:
	for i in range(type.pos_arr[orientation].size()):
		var block_pos: Vector2 = type.pos_arr[orientation][i]
		var block_color: Vector2 = type.color_arr[orientation][i]
		_set_piece_block(pos.x + block_pos.x, pos.y + block_pos.y, block_color)
	
	var should_pause := false
	if death_piece:
		pass
	elif _check_for_boxes():
		_line_clear_delay = new_line_clear_frames
		_remaining_box_build_frames = _line_clear_delay
		should_pause = true
	elif _check_for_line_clear():
		_line_clear_delay = new_line_clear_frames
		_remaining_line_clear_frames = _line_clear_delay
		should_pause = true
	else:
		_line_clear_delay = 0
	return should_pause


"""
Returns 'true' if the specified cell does not contain a block.
"""
func is_cell_empty(x: int, y: int) -> bool:
	return $TileMapClip/TileMap.get_cell(x, y) == -1


func end_game() -> void:
	_score.end_combo()
	combo = 0


"""
Deletes all cleared lines from the playfield, shifting everything above them down to fill the gap.
"""
func _delete_rows() -> void:
	_should_play_line_fall_sound = false
	for cleared_line in _cleared_lines:
		_delete_row(cleared_line)
	_cleared_lines = []
	if _should_play_line_fall_sound:
		$LineFallSound.play()


"""
Creates a new integer matrix of the same dimensions as the playfield.
"""
func _int_matrix() -> Array:
	var matrix := []
	for y in range(ROW_COUNT):
		matrix.append([])
		for _x in range(COL_COUNT):
			matrix[y].resize(COL_COUNT)
	return matrix


"""
Calculates the possible locations for a (width x height) rectangle in the playfield, given an integer matrix with the
possible locations for a (1 x height) rectangle in the playfield. These rectangles must consist of dropped pieces which
haven't been split apart by lines. They can't consist of any empty cells or any previously built boxes.
"""
func _filled_rectangles(db: Array, box_height: int) -> Array:
	var dt := _int_matrix()
	for y in range(ROW_COUNT):
		for x in range(COL_COUNT):
			if db[y][x] >= box_height:
				dt[y][x] = 1 if x == 0 else dt[y][x - 1] + 1
			else:
				dt[y][x] = 0
	return dt


"""
Calculates the possible locations for a (1 x height) rectangle in the playfield, capable of being a part of a 3x3, 3x4, or
3x5 'box'. These rectangles must consist of dropped pieces which haven't been split apart by lines. They can't consist
of any empty cells or any previously built boxes.
"""
func _filled_columns() -> Array:
	var db := _int_matrix()
	for y in range(ROW_COUNT):
		for x in range(COL_COUNT):
			var piece_color: int = $TileMapClip/TileMap.get_cell(x, y)
			if piece_color == -1:
				# empty space
				db[y][x] = 0
			elif piece_color == 1:
				# box
				db[y][x] = 0
			elif piece_color == 2:
				# vegetable
				db[y][x] = 0
			else:
				db[y][x] = 1 if y == 0 else db[y - 1][x] + 1
	return db


"""
Builds any possible 3x3, 3x4 or 3x5 'boxes' in the playfield, returning 'true' if a box was built.
"""
func _check_for_boxes() -> bool:
	# Calculate the possible locations for a (w x h) rectangle in the playfield
	var db := _filled_columns()
	var dt3 := _filled_rectangles(db, 3)
	var dt4 := _filled_rectangles(db, 4)
	var dt5 := _filled_rectangles(db, 5)
	
	for y in range(ROW_COUNT):
		for x in range(COL_COUNT):
			# check for 5x3s (vertical)
			if dt5[y][x] >= 3 and _check_for_box(x - 2, y - 4, 3, 5, true):
				$MakeCakeBoxSound.play()
				# exit box check; a dropped piece can only make one box, and making a box invalidates the db cache
				_remaining_box_build_frames = _line_clear_delay
				return true
			
			# check for 4x3s (vertical)
			if dt4[y][x] >= 3 and _check_for_box(x - 2, y - 3, 3, 4, true):
				$MakeCakeBoxSound.play()
				# exit box check; a dropped piece can only make one box, and making a box invalidates the db cache
				_remaining_box_build_frames = _line_clear_delay
				return true
			
			# check for 5x3s (horizontal)
			if dt3[y][x] >= 5 and _check_for_box(x - 4, y - 2, 5, 3, true):
				$MakeCakeBoxSound.play()
				# exit box check; a dropped piece can only make one box, and making a box invalidates the db cache
				_remaining_box_build_frames = _line_clear_delay
				return true
			
			# check for 4x3s (horizontal)
			if dt3[y][x] >= 4 and _check_for_box(x - 3, y - 2, 4, 3, true):
				$MakeCakeBoxSound.play()
				# exit box check; a dropped piece can only make one box, and making a box invalidates the db cache
				_remaining_box_build_frames = _line_clear_delay
				return true
			
			# check for 3x3s
			if dt3[y][x] >= 3 and _check_for_box(x - 2, y - 2, 3, 3):
				var box_type := int($TileMapClip/TileMap.get_cell_autotile_coord(x - 2, y - 2).y)
				if box_type == 0:
					$MakeSnackBoxSound0.play()
				elif box_type == 1:
					$MakeSnackBoxSound1.play()
				elif box_type == 2:
					$MakeSnackBoxSound2.play()
				elif box_type == 3:
					$MakeSnackBoxSound3.play()
				# exit box check; a dropped piece can only make one box, and making a box invalidates the db cache
				_remaining_box_build_frames = _line_clear_delay
				return true
	return false


"""
Checks whether the specified rectangle represents an enclosed box. An enclosed box must not connect to any pieces
outside the box.

It's assumed the rectangle's coordinates contain only dropped pieces which haven't been split apart by lines, and
no empty/vegetable/box cells.
"""
func _check_for_box(x: int, y: int, width: int, height: int, cake = false) -> bool:
	for curr_x in range(x, x + width):
		if int($TileMapClip/TileMap.get_cell_autotile_coord(curr_x, y).x) & PieceTypes.CONNECTED_UP > 0:
			return false
		if int($TileMapClip/TileMap.get_cell_autotile_coord(curr_x, y + height - 1).x) & PieceTypes.CONNECTED_DOWN > 0:
			return false
	for curr_y in range(y, y + height):
		if int($TileMapClip/TileMap.get_cell_autotile_coord(x, curr_y).x) & PieceTypes.CONNECTED_LEFT > 0:
			return false
		if int($TileMapClip/TileMap.get_cell_autotile_coord(x + width - 1, curr_y).x) & PieceTypes.CONNECTED_RIGHT > 0:
			return false
	
	# making a piece continues the combo
	_combo_break = 0
	
	var box_color := 4 if cake else $TileMapClip/TileMap.get_cell_autotile_coord(x, y).y
	
	# corners
	_set_box_block(x + 0, y + 0, Vector2(10, box_color))
	_set_box_block(x + width - 1, y + 0, Vector2(6, box_color))
	_set_box_block(x + 0, y + height - 1, Vector2(9, box_color))
	_set_box_block(x + width - 1, y + height - 1, Vector2(5, box_color))
	
	# top/bottom edge
	for curr_x in range(x + 1, x + width - 1):
		_set_box_block(curr_x, y + 0, Vector2(14, box_color))
		_set_box_block(curr_x, y + height - 1, Vector2(13, box_color))
	
	# center
	for curr_x in range(x + 1, x + width - 1):
		for curr_y in range(y + 1, y + height - 1):
			_set_box_block(curr_x, curr_y, Vector2(15, box_color))
	
	# left/right edge
	for curr_y in range(y + 1, y + height - 1):
		_set_box_block(x + 0, curr_y, Vector2(11, box_color))
		_set_box_block(x + width - 1, curr_y, Vector2(7, box_color))
	
	return true


"""
Checks whether any lines in the playfield are full and should be cleared. Updates the combo, awards points, and plays
sounds appropriately. Returns 'true' if any lines were cleared.
"""
func _check_for_line_clear() -> bool:
	var total_points := 0
	var piece_points := 0
	var lines_cleared := 0
	for y in range(ROW_COUNT):
		if _row_is_full(y):
			var line_score := 1
			line_score += COMBO_SCORE_ARR[clamp(combo, 0, COMBO_SCORE_ARR.size() - 1)]
			Global.scenario_performance.lines += 1
			Global.scenario_performance.combo_score += COMBO_SCORE_ARR[clamp(combo, 0, COMBO_SCORE_ARR.size() - 1)]
			_cleared_lines.append(y)
			for x in range(COL_COUNT):
				if $TileMapClip/TileMap.get_cell(x, y) == 1 and int($TileMapClip/TileMap.get_cell_autotile_coord(x, y).x) & PieceTypes.CONNECTED_LEFT == 0:
					if $TileMapClip/TileMap.get_cell_autotile_coord(x, y).y == 4:
						# cake piece
						line_score += 10
						Global.scenario_performance.box_score += 10
						piece_points = int(max(piece_points, 2))
					else:
						# snack piece
						line_score += 5
						Global.scenario_performance.box_score += 5
						piece_points = int(max(piece_points, 1))
			_score.add_combo_score(line_score - 1)
			_score.add_score(1)
			_clear_row(y)
			_remaining_line_clear_frames = _line_clear_delay
			line_score = max(1, line_score)
			total_points += line_score
			lines_cleared += 1
			
			# clearing lines adds to the combo
			combo += 1
			_combo_break = 0
		
	_combo_break += 1
	
	if _combo_break >= 3:
		if _score.combo_score > 0:
			if combo >= 20:
				$Fanfare3.play()
			elif combo >= 10:
				$Fanfare2.play()
			elif combo >= 5:
				$Fanfare1.play()
		if _score.customer_score > 0:
			emit_signal("customer_left")
			_score.end_combo()
			combo = 0
	
	if total_points > 0:
		_play_line_clear_sfx(piece_points)
		emit_signal("line_cleared", lines_cleared)
	
	return total_points > 0


"""
Play sound effects for clearing a line. A cleared line can result in several sound effects getting queued and played
consecutively.
"""
func _play_line_clear_sfx(piece_points: int) -> void:
	var scheduled_sfx := []
	
	# determine the main line-clear sound effect, which plays for clearing any line
	if _cleared_lines.size() == 1:
		scheduled_sfx.append($Erase1Sound)
	elif _cleared_lines.size() == 2:
		scheduled_sfx.append($Erase2Sound)
	else:
		scheduled_sfx.append($Erase3Sound)
	
	# determine any combo sound effects, which play for continuing a combo
	for combo_sfx in range(combo - _cleared_lines.size(), combo):
		if combo_sfx > 0:
			scheduled_sfx.append(_get_combo_sound(combo_sfx))
	if piece_points == 1:
		scheduled_sfx.append($ClearSnackPieceSound)
	elif piece_points >= 2:
		scheduled_sfx.append($ClearCakePieceSound)
	
	# play the calculated sound effects
	if scheduled_sfx.size() > 0:
		# play the first sound effect immediately
		scheduled_sfx[0].play()
		# enqueue other sound effects and play them later
		for sfx_index in range(1, scheduled_sfx.size()):
			yield(get_tree().create_timer(0.025 * sfx_index), "timeout")
			scheduled_sfx[sfx_index].play()


"""
Returns the combo sound which should play for the specified combo.

For smaller combos this goes through an escalating list of sound effects. For larger combos this loops through a
cyclic list of sound effects, where the cycling is masked using something resembling a shepard tone.
"""
func _get_combo_sound(combo: int) -> AudioStreamPlayer:
	var combo_sound: AudioStreamPlayer
	if combo < _combo_sound_arr.size():
		combo_sound = _combo_sound_arr[combo]
	else:
		combo_sound = _combo_sound_endless_arr[(combo - _combo_sound_arr.size()) % _combo_sound_endless_arr.size()]
	return combo_sound


"""
Returns true if the specified row has no empty cells.
"""
func _row_is_full(y: int) -> bool:
	var row_is_full := true
	for x in range(COL_COUNT):
		if is_cell_empty(x, y):
			row_is_full = false
			break
	return row_is_full


"""
Clear all cells in the specified row. This leaves any pieces above them floating in mid-air.
"""
func _clear_row(y: int) -> void:
	for x in range(COL_COUNT):
		if $TileMapClip/TileMap.get_cell(x, y) == 0:
			_disconnect_block(x, y)
		elif $TileMapClip/TileMap.get_cell(x, y) == 1:
			_disconnect_box(x, y)
		
		_clear_block(x, y)


"""
Deletes the specified row in the playfield, dropping all higher rows down to fill the gap.
"""
func _delete_row(y: int) -> void:
	for curr_y in range(y, 0, -1):
		for x in range(COL_COUNT):
			var piece_color: int = $TileMapClip/TileMap.get_cell(x, curr_y - 1)
			var autotile_coord: Vector2 = $TileMapClip/TileMap.get_cell_autotile_coord(x, curr_y - 1)
			$TileMapClip/TileMap.set_cell(x, curr_y, piece_color, false, false, false, autotile_coord)
			$TileMapClip/TileMap/CornerMap.dirty = true
			if piece_color != -1:
				# only play the line falling sound if at least one block falls
				_should_play_line_fall_sound = true
	
	# remove row
	for x in range(COL_COUNT):
		_clear_block(x, 0)


"""
Disconnects the specified block from all blocks it's connected to, directly or indirectly. All disconnected blocks are
turned into vegetables to ensure they can't be included in boxes in the future.
"""
func _disconnect_block(x: int, y: int) -> void:
	if $TileMapClip/TileMap.get_cell(x, y) != 0:
		# not a block; do nothing and don't recurse
		return
	
	# store connections
	var old_autotile_coord: Vector2 = $TileMapClip/TileMap.get_cell_autotile_coord(x, y)
	
	# disconnect
	var vegetable_type := old_autotile_coord.y
	if vegetable_type > 3:
		# unusual blocks (maybe in future development) become leafy greens
		vegetable_type = 0
	_set_veg_block(x, y, Vector2(randi() % 18, vegetable_type))
	
	if y > 0 and int(old_autotile_coord.x) & PieceTypes.CONNECTED_UP > 0:
		_disconnect_block(x, y - 1)
	
	if y < ROW_COUNT - 1 and int(old_autotile_coord.x) & PieceTypes.CONNECTED_DOWN > 0:
		_disconnect_block(x, y + 1)
	
	if x > 0 and int(old_autotile_coord.x) & PieceTypes.CONNECTED_LEFT > 0:
		_disconnect_block(x - 1, y)
	
	if x < COL_COUNT - 1 and int(old_autotile_coord.x) & PieceTypes.CONNECTED_RIGHT > 0:
		_disconnect_block(x + 1, y)


"""
Disconnects the specified block, which is a part of a box, from the boxes above and below it.

When clearing a line which contains a box, parts of the box can stay behind. We want to redraw those boxes so that
they don't look chopped-off, and so that the player can still tell they're worth bonus points, so we turn them into
smaller 2x3 and 1x3 boxes.

If we didn't perform this step, the chopped-off bottom of a bread box would still just look like bread. This way, the
bottom of a bread box looks like a delicious frosted snack and the player can tell it's special.
"""
func _disconnect_box(x: int, y: int) -> void:
	var old_autotile_coord: Vector2 = $TileMapClip/TileMap.get_cell_autotile_coord(x, y)
	if y > 0 and int(old_autotile_coord.x) & PieceTypes.CONNECTED_UP > 0:
		var above_autotile_coord: Vector2 = $TileMapClip/TileMap.get_cell_autotile_coord(x, y - 1)
		_set_box_block(x, y - 1, Vector2(int(above_autotile_coord.x) ^ PieceTypes.CONNECTED_DOWN, above_autotile_coord.y))
		_set_box_block(x, y, Vector2(int(old_autotile_coord.x) ^ PieceTypes.CONNECTED_UP, old_autotile_coord.y))
	if y < ROW_COUNT - 1 and int(old_autotile_coord.x) & PieceTypes.CONNECTED_DOWN > 0:
		var below_autotile_coord:Vector2 = $TileMapClip/TileMap.get_cell_autotile_coord(x, y + 1)
		_set_box_block(x, y + 1, Vector2(int(below_autotile_coord.x) ^ PieceTypes.CONNECTED_UP, below_autotile_coord.y))
		_set_box_block(x, y, Vector2(int(old_autotile_coord.x) ^ PieceTypes.CONNECTED_DOWN, old_autotile_coord.y))


"""
Writes a block which is a part of an intact piece into the tile map. These intact pieces might later become boxes or
vegetables.
"""
func _set_piece_block(x: int, y: int, block_color: Vector2) -> void:
	$TileMapClip/TileMap.set_cell(x, y, 0, false, false, false, block_color)
	$TileMapClip/TileMap/CornerMap.dirty = true


"""
Writes a block which is a part of a snack box or cake box into the tile map. These are typically written when the
player arranges pieces into a box.
"""
func _set_box_block(x: int, y: int, box_color: Vector2) -> void:
	$TileMapClip/TileMap.set_cell(x, y, 1, false, false, false, box_color)
	$TileMapClip/TileMap/CornerMap.dirty = true


"""
Writes a vegetable block into the tile map. These are typically written when the player breaks up an intact piece.
"""
func _set_veg_block(x: int, y: int, block_color: Vector2) -> void:
	$TileMapClip/TileMap.set_cell(x, y, 2, false, false, false, block_color)
	$TileMapClip/TileMap/CornerMap.dirty = true


"""
Erases a block from the tile map.
"""
func _clear_block(x: int, y: int) -> void:
	$TileMapClip/TileMap.set_cell(x, y, -1)
	$TileMapClip/TileMap/CornerMap.dirty = true
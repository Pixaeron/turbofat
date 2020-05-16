class_name Playfield
extends Control
"""
Stores information about the game playfield: writing pieces to the playfield, calculating whether a line was cleared
or whether a box was made, pausing and playing sound effects
"""

# signal emitted before a line is cleared
signal before_line_cleared(y, total_lines, remaining_lines)

# signal emitted when a line is cleared
signal line_cleared(y, total_lines, remaining_lines)

# signal emitted when a box (3x3, 3x4, 3x5) is made
signal box_made(x, y, width, height, color_int)

signal combo_break_changed(value)

# signal emitted when the customer should leave
signal customer_left

const CAKE_COLOR_INDEX := 4

# percent of the line clear delay which should be spent erasing lines.
# 1.0 = erase lines slowly one at a time, 0.0 = erase all lines immediately
const LINE_ERASE_TIMING_PCT := 0.667

# food colors for the food which gets hurled into the customer's mouth
const VEGETABLE_COLOR := Color("335320")
const RAINBOW_COLOR := Color.magenta
const FOOD_COLORS: Array = [
	Color("a4470b"), # brown
	Color("ff5d68"), # pink
	Color("ffa357"), # bread
	Color("fff6eb") # white
]

# playfield dimensions. the playfield extends a few rows higher than what the player can see
const ROW_COUNT = 20
const COL_COUNT = 9

# bonus points which are awarded as the player continues a combo
const COMBO_SCORE_ARR = [0, 0, 5, 5, 10, 10, 15, 15, 20]

# number of lines the player has cleared without dropping their combo
var combo := 0

# The number of pieces the player has dropped without clearing a line or making a box.
var combo_break := 0

# 'true' if the player is currently playing, and the time spent should count towards their stats
var clock_running := false

# lines which are currently being cleared
var cleared_lines := []
var _cleared_line_index := 0

# Stores timing values to ensure lines are erased one at a time with consistent timing.
# Lines are erased when '_remaining_line_clear_frames' falls below the values in this array.
var _remaining_line_clear_timings := []

# remaining frames to wait for clearing the current lines
var _remaining_line_clear_frames := 0

# remaining frames to wait for making the current box
var _remaining_box_build_frames := 0

# True if anything is dropping which will trigger the line fall sound.
var _should_play_line_fall_sound := false

func _ready() -> void:
	$TileMapClip/TileMap.clear()
	$TileMapClip/TileMap/CornerMap.clear()


func _physics_process(delta: float) -> void:
	if clock_running:
		PuzzleScore.scenario_performance.seconds += delta
	
	if _remaining_box_build_frames > 0:
		_remaining_box_build_frames -= 1
		if _remaining_box_build_frames <= 0:
			if _remaining_line_clear_frames > 0:
				_process_line_clear()
	elif _remaining_line_clear_frames > 0:
		if _cleared_line_index < cleared_lines.size() \
				and _remaining_line_clear_frames <= _remaining_line_clear_timings[_cleared_line_index]:
			clear_line(cleared_lines[_cleared_line_index], cleared_lines.size(),
					cleared_lines.size() - _cleared_line_index - 1)
			_cleared_line_index += 1

		_remaining_line_clear_frames -= 1
		if _remaining_line_clear_frames <= 0:
			_cleared_line_index = 0
			_delete_rows()


"""
Returns false the playfield is paused for an of animation or delay which should prevent a new piece from appearing.
"""
func ready_for_new_piece() -> bool:
	return _remaining_line_clear_frames <= 0 and _remaining_box_build_frames <= 0


"""
Clears the playfield and resets everything for a new game.
"""
func start_game() -> void:
	combo = 0
	$TileMapClip/TileMap.clear()
	$TileMapClip/TileMap/CornerMap.clear()
	$TileMapClip/PlayfieldFx.reset()


"""
Writes a piece to the playfield, checking whether it makes any boxes or clears any lines.

Returns true if the written piece results in a line clear.
"""
func write_piece(pos: Vector2, orientation: int, type: PieceType, death_piece := false) -> bool:
	for i in range(type.pos_arr[orientation].size()):
		var block_pos := type.get_cell_position(orientation, i)
		var block_color := type.get_cell_color(orientation, i)
		_set_piece_block(pos.x + block_pos.x, pos.y + block_pos.y, block_color)
	
	combo_break += 1
	_remaining_box_build_frames = 0
	if not death_piece and _process_boxes():
		# set at least 1 box build frame; processing occurs when the frame goes from 1 -> 0
		_remaining_box_build_frames = max(1, PieceSpeeds.current_speed.box_delay)
		combo_break = 0

	_remaining_line_clear_frames = 0
	if not death_piece and _any_row_is_full():
		# set at least line clear frame; processing occurs when the frame goes from 1 -> 0
		_remaining_line_clear_frames = max(1, PieceSpeeds.current_speed.line_clear_delay)
		combo_break = 0

		if _remaining_box_build_frames <= 0:
			# process the line clear if we're not already making a box
			_process_line_clear()

	_break_combo()
	emit_signal("combo_break_changed", combo_break)
	return _remaining_line_clear_frames > 0


"""
Returns 'true' if the specified cell does not contain a block.
"""
func is_cell_empty(x: int, y: int) -> bool:
	return get_cell(x, y) == -1


func end_game() -> void:
	PuzzleScore.end_combo()
	combo = 0


"""
Clears a full line in the playfield.

Updates the combo, awards points, and plays sounds appropriately.
"""
func clear_line(y: int, total_lines: int, remaining_lines: int) -> void:
	combo += 1
	var box_count := box_count(y)
	var combo_score: int = COMBO_SCORE_ARR[clamp(combo - 1, 0, COMBO_SCORE_ARR.size() - 1)]
	var box_score: int = 5 * (box_count % 10) + 10 * (box_count / 10)
	PuzzleScore.add_line_score(combo_score, box_score)
	emit_signal("before_line_cleared", y, total_lines, remaining_lines)
	_erase_row(y)
	emit_signal("line_cleared", y, total_lines, remaining_lines)


"""
Returns a number encapsulating the number of cake boxes and snack boxes in the specified row.

Parameters:
	'y': A row in the playfield.

Returns:
	An integer with the cake box quantity in the 10s digit, and snack box quantity in the 1s digit.
"""
func box_count(y: int) -> int:
	var result := 0
	for x in range(COL_COUNT):
		var autotile_coord: Vector2 = get_cell_autotile_coord(x, y)
		if get_cell(x, y) == 1 and not Connect.is_l(autotile_coord.x):
			result += 10 if autotile_coord.y == CAKE_COLOR_INDEX else 1
	return result


"""
Makes a box at the specified location.

Boxes are made when the player forms a 3x3, 3x4, 3x5 rectangle from intact pieces.
"""
func make_box(x: int, y: int, width: int, height: int, box_color: int) -> void:
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
		
	emit_signal("box_made", x, y, width, height, box_color)


"""
Deletes all erased rows from the playfield, shifting everything above them down to fill the gap.
"""
func _delete_rows() -> void:
	_should_play_line_fall_sound = false
	for y in cleared_lines:
		_delete_row(y)
	cleared_lines = []
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
Calculates the possible locations for a (1 x height) rectangle in the playfield, capable of being a part of a 3x3,
3x4, or 3x5 'box'. These rectangles must consist of dropped pieces which haven't been split apart by lines. They can't
consist of any empty cells or any previously built boxes.
"""
func _filled_columns() -> Array:
	var db := _int_matrix()
	for y in range(ROW_COUNT):
		for x in range(COL_COUNT):
			var piece_color: int = get_cell(x, y)
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
func _process_boxes() -> bool:
	# Calculate the possible locations for a (w x h) rectangle in the playfield
	var db := _filled_columns()
	var dt3 := _filled_rectangles(db, 3)
	var dt4 := _filled_rectangles(db, 4)
	var dt5 := _filled_rectangles(db, 5)
	
	for y in range(ROW_COUNT):
		for x in range(COL_COUNT):
			if dt5[y][x] >= 3 and _process_box(x, y, 3, 5): return true
			if dt4[y][x] >= 3 and _process_box(x, y, 3, 4): return true
			if dt3[y][x] >= 3 and _process_box(x, y, 3, 3): return true
			if dt3[y][x] >= 4 and _process_box(x, y, 4, 3): return true
			if dt3[y][x] >= 5 and _process_box(x, y, 5, 3): return true
	return false


"""
Checks whether the specified rectangle represents an enclosed box. An enclosed box must not connect to any pieces
outside the box.

It's assumed the rectangle's coordinates contain only dropped pieces which haven't been split apart by lines, and
no empty/vegetable/box cells.
"""
func _process_box(end_x: int, end_y: int, width: int, height: int) -> bool:
	var start_x := end_x - (width - 1)
	var start_y := end_y - (height - 1)
	for x in range(start_x, end_x + 1):
		if Connect.is_u(get_cell_autotile_coord(x, start_y).x):
			return false
		if Connect.is_d(get_cell_autotile_coord(x, end_y).x):
			return false
	for y in range(start_y, end_y + 1):
		if Connect.is_l(get_cell_autotile_coord(start_x, y).x):
			return false
		if Connect.is_r(get_cell_autotile_coord(end_x, y).x):
			return false
	
	var box_color: int
	if width == 3 and height == 3:
		box_color = get_cell_autotile_coord(start_x, start_y).y
	else:
		box_color = CAKE_COLOR_INDEX
	make_box(start_x, start_y, width, height, box_color)
	
	return true


"""
Returns 'true' if any rows are full and will result in a line clear when processed.
"""
func _any_row_is_full() -> bool:
	var result := false
	for y in range(ROW_COUNT):
		if _row_is_full(y):
			result = true
			break
	return result


func get_cell(x: int, y:int) -> int:
	return $TileMapClip/TileMap.get_cell(x, y)


func get_cell_autotile_coord(x: int, y:int) -> Vector2:
	return $TileMapClip/TileMap.get_cell_autotile_coord(x, y)


"""
Marks any full lines in the playfield to be cleared later.
"""
func _process_line_clear() -> void:
	for y in range(ROW_COUNT):
		if _row_is_full(y):
			cleared_lines.append(y)

	if cleared_lines:
		# Calculate the timing values when lines will be cleared.
		_remaining_line_clear_timings.clear()
		var _line_erase_timing_window := LINE_ERASE_TIMING_PCT * _remaining_line_clear_frames
		var _per_line_frame_delay := floor(_line_erase_timing_window / max(1, cleared_lines.size() - 1))
		for i in range(cleared_lines.size()):
			_remaining_line_clear_timings.append(_remaining_line_clear_frames - i * _per_line_frame_delay)


"""
Ends the player's combo if they drop 2 blocks without making a box or scoring points.
"""
func _break_combo() -> void:
	if combo_break < 2:
		return
	
	if combo >= 20:
		$Fanfare3.play()
	elif combo >= 10:
		$Fanfare2.play()
	elif combo >= 5:
		$Fanfare1.play()
	
	if PuzzleScore.get_customer_score() > 0:
		emit_signal("customer_left")
		PuzzleScore.end_combo()
		combo = 0


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
Erases all cells in the specified row. This leaves any pieces above them floating in mid-air.
"""
func _erase_row(y: int) -> void:
	for x in range(COL_COUNT):
		if get_cell(x, y) == 0:
			_disconnect_block(x, y)
		elif get_cell(x, y) == 1:
			_disconnect_box(x, y)
		
		_erase_block(x, y)


"""
Deletes the specified row in the playfield, dropping all higher rows down to fill the gap.
"""
func _delete_row(y: int) -> void:
	for curr_y in range(y, 0, -1):
		for x in range(COL_COUNT):
			var piece_color: int = get_cell(x, curr_y - 1)
			var autotile_coord: Vector2 = get_cell_autotile_coord(x, curr_y - 1)
			$TileMapClip/TileMap.set_cell(x, curr_y, piece_color, false, false, false, autotile_coord)
			$TileMapClip/TileMap/CornerMap.dirty = true
			if piece_color != -1:
				# only play the line falling sound if at least one block falls
				_should_play_line_fall_sound = true
	
	# remove row
	for x in range(COL_COUNT):
		_erase_block(x, 0)


"""
Disconnects the specified block from all blocks it's connected to, directly or indirectly. All disconnected blocks are
turned into vegetables to ensure they can't be included in boxes in the future.
"""
func _disconnect_block(x: int, y: int) -> void:
	if get_cell(x, y) != 0:
		# not a block; do nothing and don't recurse
		return
	
	# store connections
	var old_autotile_coord: Vector2 = get_cell_autotile_coord(x, y)
	
	# disconnect
	var vegetable_type := old_autotile_coord.y
	if vegetable_type > 3:
		# unusual blocks (maybe in future development) become leafy greens
		vegetable_type = 0
	_set_veg_block(x, y, Vector2(randi() % 18, vegetable_type))
	
	if y > 0 and Connect.is_u(old_autotile_coord.x):
		_disconnect_block(x, y - 1)
	
	if y < ROW_COUNT - 1 and Connect.is_d(old_autotile_coord.x):
		_disconnect_block(x, y + 1)
	
	if x > 0 and Connect.is_l(old_autotile_coord.x):
		_disconnect_block(x - 1, y)
	
	if x < COL_COUNT - 1 and Connect.is_r(old_autotile_coord.x):
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
	var old_autotile_coord: Vector2 = get_cell_autotile_coord(x, y)
	if y > 0 and Connect.is_u(old_autotile_coord.x):
		var above_autotile_coord: Vector2 = get_cell_autotile_coord(x, y - 1)
		_set_box_block(x, y - 1, Vector2(Connect.unset_d(above_autotile_coord.x), above_autotile_coord.y))
		_set_box_block(x, y, Vector2(Connect.unset_u(old_autotile_coord.x), old_autotile_coord.y))
	if y < ROW_COUNT - 1 and Connect.is_d(old_autotile_coord.x):
		var below_autotile_coord:Vector2 = get_cell_autotile_coord(x, y + 1)
		_set_box_block(x, y + 1,
				Vector2(Connect.unset_u(below_autotile_coord.x), below_autotile_coord.y))
		_set_box_block(x, y,
				Vector2(Connect.unset_d(old_autotile_coord.x), old_autotile_coord.y))


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


func _erase_block(x: int, y: int) -> void:
	$TileMapClip/TileMap.set_cell(x, y, -1)
	$TileMapClip/TileMap/CornerMap.dirty = true

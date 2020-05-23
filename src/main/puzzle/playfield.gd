class_name Playfield
extends Control
"""
Stores information about the game playfield: writing pieces to the playfield, calculating whether a line was cleared
or whether a box was made, pausing and playing sound effects
"""

signal box_made(x, y, width, height, color_int)
signal before_line_cleared(y, total_lines, remaining_lines, box_ints)
signal line_cleared(y, total_lines, remaining_lines, box_ints)
signal after_piece_written

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

# 'true' if points are awarded for the current line clears. Top outs result in line clears, but the player isn't
# awarded points for them.
var awarding_line_clear_points: bool = true
var lines_being_cleared := []

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
	PuzzleScore.connect("game_prepared", self, "_on_PuzzleScore_game_prepared")
	$TileMapClip/TileMap.clear()
	$TileMapClip/TileMap/CornerMap.clear()


func _physics_process(delta: float) -> void:
	if PuzzleScore.game_active:
		PuzzleScore.scenario_performance.seconds += delta
	
	if _remaining_box_build_frames > 0:
		_remaining_box_build_frames -= 1
		if _remaining_box_build_frames <= 0:
			if _remaining_line_clear_frames > 0:
				_schedule_full_row_line_clears()
			else:
				emit_signal("after_piece_written")
	elif _remaining_line_clear_frames > 0:
		if _cleared_line_index < lines_being_cleared.size() \
				and _remaining_line_clear_frames <= _remaining_line_clear_timings[_cleared_line_index]:
			clear_line(lines_being_cleared[_cleared_line_index], lines_being_cleared.size(),
					lines_being_cleared.size() - _cleared_line_index - 1)
			_cleared_line_index += 1

		_remaining_line_clear_frames -= 1
		if _remaining_line_clear_frames <= 0:
			_cleared_line_index = 0
			_delete_rows()
			emit_signal("after_piece_written")


func set_block(pos: Vector2, tile: int, autotile_coord: Vector2 = Vector2.ZERO) -> void:
	$TileMapClip/TileMap.set_block(pos, tile, autotile_coord)


"""
Returns false the playfield is paused for an of animation or delay which should prevent a new piece from appearing.
"""
func ready_for_new_piece() -> bool:
	return _remaining_line_clear_frames <= 0 and _remaining_box_build_frames <= 0


"""
Writes a piece to the playfield, checking whether it makes any boxes or clears any lines.

Returns true if the written piece results in a line clear.
"""
func write_piece(pos: Vector2, orientation: int, type: PieceType, death_piece := false) -> bool:
	for i in range(type.pos_arr[orientation].size()):
		var block_pos := type.get_cell_position(orientation, i)
		var block_color := type.get_cell_color(orientation, i)
		_set_block(pos + block_pos, PuzzleTileMap.TILE_PIECE, block_color)
	
	_remaining_box_build_frames = 0
	_remaining_line_clear_frames = 0
	
	if not death_piece:
		_process_boxes()
		_schedule_full_row_line_clears()
	
	if _remaining_box_build_frames == 0 and _remaining_line_clear_frames == 0:
		# If any boxes are being made or lines are being cleared, we emit the
		# signal later. Otherwise we emit it now.
		emit_signal("after_piece_written")
	
	return _remaining_line_clear_frames > 0


"""
Returns 'true' if the specified cell does not contain a block.
"""
func is_cell_empty(x: int, y: int) -> bool:
	return get_cell(x, y) == -1


"""
Clears a full line in the playfield.

Updates the combo, awards points, and plays sounds appropriately.
"""
func clear_line(y: int, total_lines: int, remaining_lines: int) -> void:
	var box_ints: Array = []
	for x in range(COL_COUNT):
		var autotile_coord := get_cell_autotile_coord(x, y)
		if get_cell(x, y) == 1 and not Connect.is_l(autotile_coord.x):
			box_ints.append(autotile_coord.y)
	box_ints.shuffle()
	
	if awarding_line_clear_points:
		$ComboTracker.add_combo_and_score(y, total_lines, remaining_lines, box_ints)
	
	emit_signal("before_line_cleared", y, total_lines, remaining_lines, box_ints)
	_erase_row(y)
	emit_signal("line_cleared", y, total_lines, remaining_lines, box_ints)


func break_combo() -> void:
	$ComboTracker.break_combo()


"""
Makes a box at the specified location.

Boxes are made when the player forms a 3x3, 3x4, 3x5 rectangle from intact pieces.
"""
func make_box(x: int, y: int, width: int, height: int, box_int: int) -> void:
	# set at least 1 box build frame; processing occurs when the frame goes from 1 -> 0
	_remaining_box_build_frames = max(1, PieceSpeeds.current_speed.box_delay)
	$TileMapClip/TileMap.make_box(x, y, width, height, box_int)
	emit_signal("box_made", x, y, width, height, box_int)


"""
Deletes all erased rows from the playfield, shifting everything above them down to fill the gap.
"""
func _delete_rows() -> void:
	_should_play_line_fall_sound = false
	for y in lines_being_cleared:
		_delete_row(y)
	lines_being_cleared = []
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
	
	var box_int: int
	if width == 3 and height == 3:
		box_int = get_cell_autotile_coord(start_x, start_y).y
	else:
		box_int = PuzzleTileMap.BoxInt.CAKE
	make_box(start_x, start_y, width, height, box_int)
	
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


func schedule_line_clears(lines_to_clear: Array, line_clear_delay: int, award_points: bool = true) -> void:
	lines_being_cleared = lines_to_clear
	awarding_line_clear_points = award_points
	
	# Calculate the timing values when lines will be cleared. Set at least line
	# clear frame; processing occurs when the frame goes from 1 -> 0
	_remaining_line_clear_frames = max(1, line_clear_delay)
	_remaining_line_clear_timings.clear()
	var _line_erase_timing_window := LINE_ERASE_TIMING_PCT * _remaining_line_clear_frames
	var _per_line_frame_delay := floor(_line_erase_timing_window / max(1, lines_being_cleared.size() - 1))
	for i in range(lines_being_cleared.size()):
		_remaining_line_clear_timings.append(_remaining_line_clear_frames - i * _per_line_frame_delay)


"""
Marks any full lines in the playfield to be cleared later.
"""
func _schedule_full_row_line_clears() -> void:
	var lines_to_clear := []
	for y in range(ROW_COUNT):
		if _row_is_full(y):
			lines_to_clear.append(y)
	if lines_to_clear:
		schedule_line_clears(lines_to_clear, PieceSpeeds.current_speed.line_clear_delay)


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
			_convert_piece_to_veg(x, y)
		elif get_cell(x, y) == 1:
			_disconnect_box(x, y)
		
		_set_block(Vector2(x, y), PuzzleTileMap.TILE_EMPTY)


"""
Deletes the specified row in the playfield, dropping all higher rows down to fill the gap.
"""
func _delete_row(y: int) -> void:
	for curr_y in range(y, 0, -1):
		for x in range(COL_COUNT):
			var piece_color: int = get_cell(x, curr_y - 1)
			var autotile_coord: Vector2 = get_cell_autotile_coord(x, curr_y - 1)
			$TileMapClip/TileMap.set_block(Vector2(x, curr_y), piece_color, autotile_coord)
			if piece_color != -1:
				# only play the line falling sound if at least one block falls
				_should_play_line_fall_sound = true
	
	# remove row
	for x in range(COL_COUNT):
		_set_block(Vector2(x, 0), PuzzleTileMap.TILE_EMPTY)


"""
Deconstructs the piece at the specified location into vegetable blocks.
"""
func _convert_piece_to_veg(x: int, y: int) -> void:
	# store connections
	var old_autotile_coord: Vector2 = get_cell_autotile_coord(x, y)
	
	# convert to vegetable. there are four kinds of vegetables
	var vegetable_type := int(old_autotile_coord.y) % 4
	_set_block(Vector2(x, y), PuzzleTileMap.TILE_VEG, Vector2(randi() % 18, vegetable_type))
	
	# recurse to neighboring connected cells
	if get_cell(x, y - 1) == 0 and Connect.is_u(old_autotile_coord.x):
		_convert_piece_to_veg(x, y - 1)
	if get_cell(x, y + 1) == 0 and Connect.is_d(old_autotile_coord.x):
		_convert_piece_to_veg(x, y + 1)
	if get_cell(x - 1, y) == 0 and Connect.is_l(old_autotile_coord.x):
		_convert_piece_to_veg(x - 1, y)
	if get_cell(x + 1, y) == 0 and Connect.is_r(old_autotile_coord.x):
		_convert_piece_to_veg(x + 1, y)


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
	$TileMapClip/TileMap.disconnect_block(x, y - 1, Connect.DOWN)
	$TileMapClip/TileMap.disconnect_block(x, y + 1, Connect.UP)


"""
Writes a block into the tile map.
"""
func _set_block(pos: Vector2, tile: int, autotile_coord: Vector2 = Vector2.ZERO) -> void:
	$TileMapClip/TileMap.set_block(pos, tile, autotile_coord)


"""
Clears the playfield.
"""
func _on_PuzzleScore_game_prepared() -> void:
	$TileMapClip/TileMap.clear()
	$TileMapClip/TileMap/CornerMap.clear()

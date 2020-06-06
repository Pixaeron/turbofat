extends Node2D
"""
Generates visual lighting effects for the playfield.

These effects are pretty to look at, but also provide feedback if the player's combo is about to end.
"""

# Number of hues present when displaying a rainbow
const RAINBOW_COLOR_COUNT := 7

# Lights change color based on the lines the player clears.
const VEGETABLE_LIGHT_COLOR := Color("6074a320")
const FOOD_LIGHT_COLORS: Array = [
	Color("c0f47700"), # brown
	Color("b0ff5d68"), # pink
	Color("c0ffc357"), # bread
	Color("a0fff69b"), # white
]

# Rainbows are modulated white, because the tiles themselves have a color to them.
const RAINBOW_LIGHT_COLOR := Color("50ffffff")

# Light pattern shown when the player clears a line or continues their combo.
const ON_PATTERN: Array = [
	"....#....",
	"...###...",
	"..#####..",
	".#######.",
	"####.####",
	"###...###",
	"##.....##",
	"#.......#",
]

# Light pattern shown when the player's combo is about to end.
const HALF_PATTERN: Array = [
	"....#....",
	"...#.#...",
	"..#.#.#..",
	".#.#.#.#.",
	"#.#...#.#",
	".#.....#.",
	"#.......#",
	".........",
]

# Light pattern shown when the player has no combo.
const OFF_PATTERN: Array = [
	".........",
]

onready var _combo_tracker: ComboTracker = $"../../ComboTracker"

# light pattern being shown.
var _pattern := OFF_PATTERN

# offset used for displaying the light pattern, as well as for rainbow colors
var _pattern_y := 0

# number of 'elapsed beats' used for pulsing the lights. The length of a beat varies based on the piece speed, one
# beat is the amount of time an expert player would take to clear a line.
var _elapsed_beats := 0.0

# brightness of the background lights
var _brightness := 0.0

# how much the background lights dim when pulsing.
# 1.0 = pulsing completely on and off, 0.0 = not pulsing at all
var _pulse_amount := 0.0

# how long the lights remain on after a line clear
var _glow_duration := 0.0

# the current background light color
var _color := Color.transparent

# tile indexes for each food/vegetable color
var _color_tile_indexes: Dictionary

func _ready() -> void:
	reset()
	PuzzleScore.connect("game_prepared", self, "_on_PuzzleScore_game_prepared")
	_init_tile_set()


func _process(delta: float) -> void:
	_elapsed_beats += delta * (60.0 / RankCalculator.min_frames_per_line(PieceSpeeds.current_speed))
	modulate.a = lerp(_brightness * (1 - _pulse_amount), _brightness, 0.5 + 0.5 * cos(_elapsed_beats * TAU))


func reset() -> void:
	_pattern = OFF_PATTERN
	_color = Color.transparent
	$LightMap.modulate = Color.transparent
	$GlowMap.modulate = Color.transparent
	_calculate_brightness(0)
	_refresh_tilemaps(0)


func _init_tile_set() -> void:
	if len($LightMap.tile_set.get_tiles_ids()) > 1:
		return
	
	for food_light_color in FOOD_LIGHT_COLORS:
		_init_tile(food_light_color)
	
	_init_tile(VEGETABLE_LIGHT_COLOR)
	
	for i in range(RAINBOW_COLOR_COUNT):
		var rainbow_color := Utils.to_transparent(Color.red, 0.60)
		rainbow_color.h += i / float(RAINBOW_COLOR_COUNT)
		_init_tile(rainbow_color)


func _init_tile(color: Color) -> void:
	for tile_set in [$LightMap.tile_set, $GlowMap.tile_set]:
		var tile_index := len(tile_set.get_tiles_ids())
		_color_tile_indexes[color] = tile_index
		tile_set.create_tile(tile_index)
		tile_set.tile_set_texture(tile_index, tile_set.tile_get_texture(0))
		tile_set.tile_set_material(tile_index, tile_set.tile_get_material(0))
		tile_set.tile_set_modulate(tile_index, color)
		tile_set.tile_set_texture_offset(tile_index, tile_set.tile_get_texture_offset(0))


"""
Starts the glow tween, causing the lights to slowly dim.
"""
func _start_glow_tween() -> void:
	if _brightness > 0 and _glow_duration > 0.0:
		$GlowTween.remove_all()
		$GlowTween.interpolate_property($LightMap, "modulate:a", 1.00, 0.50,
			_glow_duration, Tween.TRANS_CIRC, Tween.EASE_OUT)
		$GlowTween.interpolate_property($GlowMap, "modulate:a", 0.75, 0.125,
			_glow_duration, Tween.TRANS_CIRC, Tween.EASE_OUT)
		$GlowTween.interpolate_property($BgStrobe, "color:a", 0.33, 0.00,
			_glow_duration, Tween.TRANS_CIRC, Tween.EASE_OUT)
		$GlowTween.start()


"""
Calculates the RGB light color for a row in the playfield.
"""
func _calculate_line_color(box_ints: Array) -> void:
	if box_ints.empty():
		# vegetable
		_color = VEGETABLE_LIGHT_COLOR
	elif box_ints.has(PuzzleTileMap.BoxInt.CAKE):
		# cake box
		_color = RAINBOW_LIGHT_COLOR
	elif box_ints.size() == 1 or FOOD_LIGHT_COLORS[box_ints[0]] != _color:
		# snack box
		_color = FOOD_LIGHT_COLORS[box_ints[0]]
	else:
		# avoid showing the same color twice if we can help it
		_color = FOOD_LIGHT_COLORS[box_ints[1]]


"""
Calculates the brightness of the lights based on the current combo.
"""
func _calculate_brightness(combo: int) -> void:
	_elapsed_beats = 0.0
	if combo >= 12:
		# 100% opacity flashing lights is hard on the eyes. even at max combo, we dial it back from 100%
		_brightness = lerp(0.30, 0.60, smoothstep(12, 40, combo))
		_pulse_amount = lerp(0.10, 0.30, smoothstep(12, 30, combo))
		_glow_duration = lerp(0.60, 2.40, smoothstep(12, 100, combo))
	elif combo >= 5:
		# We quickly ramp from a low brightness to medium brightness. Low brightness has some visual artifacts.
		_brightness = lerp(0.10, 0.30, smoothstep(5, 12, combo))
		_pulse_amount = lerp(0.00, 0.00, smoothstep(10, 12, combo))
		_glow_duration = lerp(0.30, 0.60, smoothstep(5, 12, combo))
	else:
		# Combos smaller than 5 do not cause lights to appear.
		_brightness = 0.0
		_pulse_amount = 0.0
		_glow_duration = 0.0
	modulate.a = _brightness


"""
Calculates the new light pattern and refreshes the tilemaps.
"""
func _refresh_tilemaps(combo: int) -> void:
	$BgStrobe.color = Utils.to_transparent(_color)
	
	var new_pattern: Array
	match _combo_tracker.combo_break:
		0: new_pattern = ON_PATTERN
		1: new_pattern = HALF_PATTERN
		_: new_pattern = OFF_PATTERN
	_pattern = new_pattern
	
	for y in range(Playfield.ROW_COUNT):
		for x in range(Playfield.COL_COUNT):
			var s: String = _pattern[(y + _pattern_y) % _pattern.size()]
			var tile: int = -1
			if s[x] == '#':
				if _color == RAINBOW_LIGHT_COLOR:
					tile = 6 + ((x + _pattern_y) % RAINBOW_COLOR_COUNT)
				elif _color_tile_indexes.has(_color):
					tile = _color_tile_indexes[_color]
			$LightMap.set_cell(x, y, tile)
			$GlowMap.set_cell(x, y, tile)


func _on_Playfield_before_line_cleared(y: int, total_lines: int, remaining_lines: int, box_ints: Array) -> void:
	_calculate_brightness(_combo_tracker.combo)
	_calculate_line_color(box_ints)
	_pattern_y += 1
	_start_glow_tween()
	_refresh_tilemaps(_combo_tracker.combo)


"""
When the player's combo breaks or resets we update the lights.
"""
func _on_ComboTracker_combo_break_changed(value: int) -> void:
	if value >= 2:
		if _pattern != OFF_PATTERN:
			reset()
			_refresh_tilemaps(value)
	else:
		_refresh_tilemaps(value)


"""
When the player makes a box we brighten the combo lights again.
"""
func _on_Playfield_box_made(x: int, y: int, width: int, height: int, color_int: int) -> void:
	_refresh_tilemaps(_combo_tracker.combo)
	_start_glow_tween()


func _on_PuzzleScore_game_prepared() -> void:
	reset()

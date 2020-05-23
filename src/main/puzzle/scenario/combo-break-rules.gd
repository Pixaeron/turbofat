class_name ComboBreakRules
"""
Things that disrupt the player's combo.
"""

# 'true' if clearing a vegetable row (a row with no snack/cake blocks) breaks their combo
var veg_row := false

# by default, dropping 2 pieces breaks their combo
var pieces := 2

"""
Populates this object with json data.
"""
func from_string_array(strings: Array) -> void:
	var rules := RuleParser.new(strings)
	if rules.has("veg-row"): veg_row = true
	if rules.has("pieces"): pieces = rules.int_value()

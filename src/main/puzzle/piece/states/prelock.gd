extends State
"""
The piece has locked into position. The player can still press 'down' to unlock it or squeeze it past other blocks.
"""

func update(piece_manager: PieceManager) -> String:
	var new_state_name := ""
	if piece_manager.apply_player_input():
		new_state_name = "MovePiece"
	elif frames >= piece_manager.piece_speed.post_lock_delay:
		var spawn_delay: float
		if piece_manager.write_piece_to_playfield():
			# line was cleared; different appearance delay
			spawn_delay = piece_manager.piece_speed.line_appearance_delay
		else:
			spawn_delay = piece_manager.piece_speed.appearance_delay
		piece_manager.active_piece.spawn_delay = spawn_delay
		new_state_name = "WaitForPlayfield"
	
	return new_state_name
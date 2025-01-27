class_name WalkingBuddy
extends Creature
"""
A creature who walks in a straight line alongside another creature.

The creature can be designated a 'leader' or a 'follower' which alters their walking behavior. The leader continues
walking as long as they're not too far from the follower. The follower continues walking until they get too close to
the leader.
"""

enum LeaderOrFollower {
	NONE,
	LEADER,
	FOLLOWER
}

enum WalkState {
	SITTING, # sitting still, emoting with their hands and facing each other
	WALKING, # following/leading each other, pausing briefly to wait for each other
	ABOUT_TO_SIT, # preparing to sit
	ABOUT_TO_WALK, # preparing to walk
}

# creatures try to keep a respectable distance from one another
const TOO_CLOSE_THRESHOLD := 200.0
const TOO_FAR_THRESHOLD := 600.0

# the direction the creatures walk, when they're walking
const WALK_DIR := Vector2(0.70710678118, 0.70710678118)

# the path to the other creature whom this creature is walking with
export (NodePath) var buddy_path: NodePath

# the path to the destination. the leader stops walking if they reach this destination
export (NodePath) var destination_path: NodePath

# designates this creature as either a leader or follower
export (LeaderOrFollower) var leader_or_follower: int

# the creature's walking state. they start out in the WALKING state, but might change to the SITTING state if they
# reach their destination or if the cutscene specifies to stop.
var _walk_state: int = WalkState.WALKING

# the other creature whom this creature is walking with
onready var buddy: Creature = get_node(buddy_path)

# the leader stops walking if they reach this destination
onready var destination: Node2D = get_node(destination_path)

# the creature reevaluates whether they should continue walking when this timer times out
onready var _move_timer: Timer = $MoveTimer

func _ready() -> void:
	if creature_id == CreatureLibrary.PLAYER_ID:
		ChattableManager.player = self
		set_creature_def(PlayerData.creature_library.player_def)
		creature_id = CreatureLibrary.PLAYER_ID
	if creature_id == CreatureLibrary.SENSEI_ID:
		ChattableManager.sensei = self
	_move_timer.connect("timeout", self, "_on_MoveTimer_timeout")
	set_non_iso_walk_direction(WALK_DIR)


"""
Makes the creature stop walking and sit down.

They will only continue walking if the 'start_walking' method is called.
"""
func stop_walking(delay: float = 0.0) -> void:
	if delay == 0:
		# sit immediately so that we can emote with our hands
		_walk_state = WalkState.SITTING
		_sit_and_reorient()
	else:
		_walk_state = WalkState.ABOUT_TO_SIT
		_start_move_timer(delay)


"""
Makes the creature resume walking.
"""
func start_walking(delay: float = 0.0) -> void:
	_walk_state = WalkState.ABOUT_TO_WALK
	_start_move_timer(delay)


"""
Starts the move timer, but preserves the default wait time.

This allows the move timer to have a longer one-time delay without changing its permanent behavior.
"""
func _start_move_timer(delay: float) -> void:
	var old_wait_time := _move_timer.wait_time
	_move_timer.start(delay)
	_move_timer.wait_time = old_wait_time


"""
Updates the creature's walk direction. This usually causes them to walk, but they might pause too.

Creatures will pause if they get too far apart or too close together. This is to allow for situations where one
creature moves faster than the other. As long as they're an appropriate distance apart, this method will make them
walk towards their destination.
"""
func _walk() -> void:
	var buddy_relative_pos: Vector2 = Global.from_iso(buddy.position - position)
	
	var new_non_iso_walk_direction := non_iso_walk_direction
	if leader_or_follower == LeaderOrFollower.LEADER:
		if Global.from_iso(position).x > Global.from_iso(destination.position).x:
			# we're past our destination. stop moving, and face our buddy
			_walk_state = WalkState.SITTING
			_sit_and_reorient()
			new_non_iso_walk_direction = Vector2.ZERO
		elif non_iso_walk_direction and buddy_relative_pos.length() > TOO_FAR_THRESHOLD:
			# we're too far from our buddy, and they're following us. stop moving
			new_non_iso_walk_direction = Vector2.ZERO
		elif not non_iso_walk_direction and buddy_relative_pos.length() < lerp(TOO_CLOSE_THRESHOLD, TOO_FAR_THRESHOLD, 0.2):
			# we're too close to our buddy, and they're following us. start moving
			new_non_iso_walk_direction = WALK_DIR
	elif leader_or_follower == LeaderOrFollower.FOLLOWER:
		if not non_iso_walk_direction and buddy_relative_pos.length() > lerp(TOO_CLOSE_THRESHOLD, TOO_FAR_THRESHOLD, 0.8):
			# we're too far from our buddy, and they're leading us. start moving
			new_non_iso_walk_direction = WALK_DIR
		elif non_iso_walk_direction and buddy_relative_pos.length() < TOO_CLOSE_THRESHOLD:
			# we're too close to our buddy, and they're leading us. stop moving
			new_non_iso_walk_direction = Vector2.ZERO
	
	if new_non_iso_walk_direction != non_iso_walk_direction:
		set_non_iso_walk_direction(new_non_iso_walk_direction)


"""
Makes the creature stop walking, sit, and face towards their friend.
"""
func _sit_and_reorient() -> void:
	set_non_iso_walk_direction(Vector2.ZERO)
	# If we don't zero out the creature's velocity, CreatureVisuals overwrites our assigned orientation
	set_non_iso_velocity(Vector2.ZERO)
	orient_toward(buddy.position)


"""
When the move timer times out, we evaluate our walk state and change the creature's behavior.
"""
func _on_MoveTimer_timeout() -> void:
	match _walk_state:
		WalkState.ABOUT_TO_SIT:
			# sit down and face our friend
			_walk_state = WalkState.SITTING
			_sit_and_reorient()
		WalkState.ABOUT_TO_WALK:
			# start walking, unless we're too close or too far
			_walk_state = WalkState.WALKING
			set_non_iso_walk_direction(WALK_DIR)
			_walk()
		WalkState.SITTING:
			# continue sitting
			pass
		WalkState.WALKING:
			# continue walking
			_walk()

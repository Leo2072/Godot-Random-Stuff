extends KinematicBody2D


#To do: create a snap function. The safe margin can sometimes separate the player from the platform too much.
#This messes up things from PlatformVelocity to OnFloor checks.
#It can somewhat be fixed by snapping the player back to the floor when they are separated too much by the margin.


func _ready() -> void:
	pass


export var vel: Vector2 = Vector2(0, 0);
export var Acceleration: float = 1000;


#The height of the object in pixels. Used to determine how high it needs to be teleported for stairs to work.
export var Height: float = 10;


export var Speed: float = 200;

#Due to accuracy for floats, the velocity will be in the vertical direction entirely, even if the object does not move.
#This can prevent objects from stopping on slopes.
export var MinSlopeHorizontalVelocity: float = 10;
#MinSlopeHorizontalVelocity takes this into account and prevent sliding if the horizontal component is below a threshold.
#If you want to prevent sliding solely based on the magnitude of the slide, just set this value very high

#It is not quite "realistic" to fall onto a slope quickly and just stop without even sliding.
#Where does all that vertical velocity even go?
export var MaxSlideResistance: float = 9999;
#MaxSlideResistance takes that slide component into account and causes an object to slide if it exceeds the threshold.
#If you want to treat a slope and flat ground the same in terms of sliding, just set this value very high.

#Sometimes, if the gravity is too small, no collision might be detected even when the object is visibly on the floor.
#This is because the movement in the direction towards the floor is smaller than the safe margin.
export var SnapLength: float = 6;
#SnapVector snaps an object to another if the object moved by the vector (directly, not as a velocity) collides.
#This can counteract the problem above, but setting it too high can prevent the character from jumping.


#If the height of a vertical wall (collision normal is perpendicular with the DownDirection),
#Then the Player will teleport in the DownDirection, on top of the wall if the move distance is less than StairStepHeight.
export var StairStepHeight: float = 6;
#Note that the Player will not be able to teleport of the ceiling on top of the step is low enough.
#Even if the ceiling is high enough to accomodate for the Player on the step,
#this still fails if the Player after teleporting a distance of StairStepHeight/StairStepCheckAccuracy can
#Hit the ceiling while moving in the direction perpendicular to the DownDireciton.

#To minimize the impact of the failure above, StairStepCheck is used to conduct the height check in smaller, discrete steps.
#Each step will travel a distance of StairStepHeight/StairStepCheckAccuracy for a total of StairStepCheckAccuracy times.
export var StairStepCheckAccuracy: int = 1;
#I recommend keeping this low, because every check creates at least 2 collision checks, 3 if it's the final one.


export var font: Font;


var Platform: PhysicsBody2D = null;
var OnFloor: bool = false;

func _input(event: InputEvent) -> void:
	if (event.is_action_pressed("ui_up") and OnFloor):
		vel -= Vector2(0, 500);
		OnFloor = false;


#_physics_process will be called later on in the frame if it uses either move_and_slide() or move_and_collide() method.
#The platform velocity is not added when moving downward.
#It seems like the way move_and_slide() works is that the platform_velocity is stored separately.
#Then, whenever there are no more platforms in contact, platform_velocity is applied to the return value of move_and_slide.
func _physics_process(delta: float) -> void:
	var PlatformVelocity: Vector2 = Vector2.ZERO;
	if Platform != null:
		PlatformVelocity =  Physics2DServer.body_get_direct_state(Platform.get_rid()).linear_velocity;
	
	var HorizontalInput: int = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"));
	vel.x = move_toward(vel.x, PlatformVelocity.x + HorizontalInput * Speed, Acceleration * delta);
	
	vel += Vector2(0, 980) * delta;
	vel = CharacterMove(vel, delta, Vector2(0, 1), SnapLength, MinSlopeHorizontalVelocity, MaxSlideResistance,
		true, StairStepHeight, StairStepCheckAccuracy);
	return;


#DownDirection is the direction gravity is facing. This should be normalized.
func CharacterMove(velocity: Vector2, delta: float, DownDirection: = Vector2(0, 1), Snap: float = 0,
HorizontalVelocityThreshold: float = 0.1, SlideResistance: float = 10, PreventSlidingByGravity: = false,
MaxStepHeight: float = 6, StepCheckCount: int = 1, slides: int = 4) -> Vector2:
	var move: Vector2;
	var col: KinematicCollision2D

#Move the character with the velocity of its platform to try keeping the its relative position on the platform the same.
	if Platform != null:
		var PlatformBodyState: Physics2DDirectBodyState = Physics2DServer.body_get_direct_state(Platform.get_rid());
#This part is to sync the character with the platform locally, so it should not collide with the platform.
		add_collision_exception_with(Platform);
#Move the Character by the platform's velocity to handle the following collisions locally.
		move = PlatformBodyState.linear_velocity * delta;
		col = move_and_collide(move);
#If a collision happens, revert back to global space and handle the input accordingly.
		if col != null:
			move = col.remainder;
		else:
			move = Vector2.ZERO;
#Now move the character locally.
#Because the move already has the velocity of the platform, we just need to add the local velocity relative to the platform.
		move += (velocity - PlatformBodyState.linear_velocity) * delta;
#Since the move will now be handled locally, make it so that we can still collide with the platform again.
		remove_collision_exception_with(Platform);
	else:
		move = velocity * delta;

	var WasOnFloor: bool = OnFloor;
	Platform = null;
	OnFloor = false;
	for slide in range(0, slides):
		var _temp: Vector2 = velocity;
		col = move_and_collide(move);
		if col != null:
			move = col.remainder;
#Converts velocity to be relative to the collider so it can be handled the same way as collisions with static bodies.
			var LocalVelocity: Vector2 = velocity - col.collider_velocity;
#Sometimes, a collision might be reported, even if it is physically impossible in real life.
#This is very rare, but should technically be possible due to discrete physics simulation.
#When the dot product is negative, that means the object in local space has and will continue to move into the surface.
#If not, that means the object is moving away from the surface locally.
			if col.normal.dot(LocalVelocity) < 0:
#If the Player is moving on a floor and hits a wall perpendicular to the DownDirection, check if it's a stair step.
				if OnFloor or WasOnFloor and is_equal_approx(col.normal.dot(DownDirection), 0):
					var StepHeight = GetStepHeight(LocalVelocity, DownDirection, MaxStepHeight/StepCheckCount, StepCheckCount);
#If the step is too high, treat it as a wall. Otherwise, teleport the Player up to the step's height and continue the move.
#Do note that if in the weird case where the height is exactly 0,
#(For whatever reasons - a collision shouldn't have even happened in such a case!)
#The "step" is basically either a flat extension of Player's current standing ground, or a spike (see GetStepHeight notes).
#Either way, it's best to treat it as if a step has not happened and slide the motion as usual.
					if StepHeight > 0 and StepHeight < MaxStepHeight:
						global_position += -DownDirection * StepHeight;
						continue;
				
				if PreventSlidingByGravity and slide == 0:
					var DownIntensity: float = DownDirection.dot(LocalVelocity);
#Ensure that the player is sliding down due to Gravity.
#Upward Sliding is just the usual inputted velocity slid up by a slope.
					if DownIntensity > 0:
#If the component of the move in the direction perpendicular to gravity is less than the  HorizontalVelocityThreshold,
#and the slide is shorter than the SlideResistance, cancel the move completely.
						if (abs(DownDirection.cross(LocalVelocity)) < HorizontalVelocityThreshold
						and abs(LocalVelocity.cross(col.normal)) < SlideResistance):
							LocalVelocity = Vector2.ZERO;
							move = Vector2.ZERO;
						else:
#Slide the velocity and the move vectors along the collision surface.
							LocalVelocity = LocalVelocity.slide(col.normal);
							move = move.slide(col.normal);
				else:
#Slide the velocity and the move vectors along the collision surface.
					LocalVelocity = LocalVelocity.slide(col.normal);
					move = move.slide(col.normal);
				Platform = col.collider;
				OnFloor = true;
			else:
				move = move.slide(col.normal);
#Converts the processed LocalVelocity back to global and assign it back to velocity.
			velocity = LocalVelocity + col.collider_velocity;
			if move.length_squared() == 0:
				break;
		else:
			break;

	if WasOnFloor and !OnFloor:
		col = move_and_collide(Snap * DownDirection, true, true, true);
		if col:
			var LocalVelocity: Vector2 = velocity - col.collider_velocity;
#I cannot perform a check to see if a collision actually happens.
#This is because the previous sliding may have removed certain components such as gravity.
			if PreventSlidingByGravity:
				var DownIntensity: float = DownDirection.dot(LocalVelocity);
				if DownIntensity > 0:
					if (abs(DownDirection.cross(LocalVelocity)) < HorizontalVelocityThreshold
					and abs(LocalVelocity.cross(col.normal)) < SlideResistance):
						LocalVelocity = Vector2.ZERO;
					else:
						LocalVelocity = LocalVelocity.slide(col.normal);
			else:
				LocalVelocity = LocalVelocity.slide(col.normal);
			Platform = col.collider;
			OnFloor = true;
			velocity = LocalVelocity + col.collider_velocity;
#If a snap can be performed, do it.
#The projection is to counteract the bug where objects slide slightly when using move_and_collide.
			global_position += col.travel.project(DownDirection.normalized());
	return velocity;
#Fun fact: I know a lot of this can be further simplified. Please, DO NOT DO THAT!
#It's better to make your code more comprehensible than to make it run a few millisecond faster.


#This is for getting the height of the ground immediately to the side of the Player in a given direction.
#Do note that it is mostly intended to find the height of a stair step.
#The smaller the StepCheckHeight, the more accurate the check will be.
#However, the Player will only be able to cross over steps with height less than or equal to StepCheckHeight * CheckCount.
#The greater the CheckCount, the more collision checks there will be.
#If the Player cannot cross over the step (it's a wall - or a very game-breakingly sharp spike), INF will be returned.
func GetStepHeight(LocalVelocity: Vector2, DownDirection: Vector2 = Vector2(0, 1),
StepCheckHeight: float = 0.5, CheckCount: int = 1) -> float:
	var col: KinematicCollision2D;
	var motion: Vector2;
	var OriginalPosition: Vector2 = global_position;
	var height: float = INF;
	var VerticalMove: float = 0;
	for _StepCount in range(0, CheckCount):
#Cast up, check if a ceiling is hit.
		motion = -DownDirection * StepCheckHeight;
		col = move_and_collide(motion, true, true, true);
#If yes, the Player can no longer move up and this will be the last StepCheck, so break at the end.
		if col:
#Temporarily move the Player along the cast to continue the next checks.
			global_position += col.travel;
#Record the height that has been travelled, add it to the height travelled in previous steps.
			VerticalMove += col.travel.length();
#Cast in the direction perpendicular to DownDirection so the Player just barely move into/onto the step.
			motion = LocalVelocity.slide(DownDirection).normalized() * 0.1;
			col = move_and_collide(motion, true, true, true);
#If a collision happens, that means this is a wall the Player cannot pass. If not, it's a stair step that can be climbed.
			if col == null:
#Temporarily move the Player along the cast so they are on the step.
				global_position += motion;
#Cast down by the height that has been travelled to see how high the Player is compared to the step.
#This is the unnecessary height component.
				motion = DownDirection * VerticalMove;
				col = move_and_collide(motion, true, true, true);
#The remaining height is the actual height of the step (give or take the safe margin because of how move_and_collide works).
#Ideally, there should always be a collision unless some weird stuff I hadn't accounted for happens.
#However, just in case there aren't the VerticalMove should always be high enough to make the Player step through.
				if col: height = col.remainder.length();
				else: height = VerticalMove;
			break;
#If not, the Player might still be able to move up, so only break when the step's height is determined.
		else:
#Temporarily move the Player along the cast to continue the next checks.
			global_position += motion;
#Record the height that has been travelled, add it to the height travelled in previous steps.
			VerticalMove += StepCheckHeight;
#Cast in the direction perpendicular to DownDirection so the Player just barely move into/onto the step.
			motion = LocalVelocity.slide(DownDirection).normalized() * 0.1;
			col = move_and_collide(motion, true, true, true);
#If a collision happens, that means this is a wall the Player cannot pass. If not, it's a stair step that can be climbed.
			if col == null:
#Temporarily move the Player along the cast so they are on the step.
				global_position += motion;
				motion = DownDirection * VerticalMove;
				col = move_and_collide(motion, true, true, true);
#The remaining height is the actual height of the step (give or take the safe margin because of how move_and_collide works).
#Again, Just in case there aren't any collisions, the VerticalMove should be high enough to make the Player step through.
				if col: height = col.remainder.length();
				else: height = VerticalMove;
				break;
	global_position = OriginalPosition;
	return height;


func _draw() -> void:
	var pos: float = name.length() * (-0.5);
	for letter in name:
# warning-ignore:return_value_discarded
		draw_char(font, Vector2(pos * 16, -20), letter, "");
		pos += 1;
	#draw_line(Vector2.ZERO, vel, Color(1, 1, 1, 1));

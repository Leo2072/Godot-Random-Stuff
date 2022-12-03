extends KinematicBody2D


# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"


export var vel: Vector2 = Vector2(300, 0);
export var font: Font;
export var Speed: float = 200;
export var Acceleration: float = 1000;
export var SnapVector: Vector2 = Vector2(9000, 300);


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		position.y -= 100;
		j = true;

var j: bool = false;

func _physics_process(delta: float) -> void:
	var HorizontalInput: int = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"));
	vel.x = move_toward(vel.x, HorizontalInput * Speed, Acceleration * delta);
	vel += Vector2(0, 980) * delta;
	vel = move_and_slide_with_snap(vel, SnapVector, Vector2(0, -1), true);
	if j:
		print("Called at " + Time.get_time_string_from_system() + " | Is it on the floor? " + String(is_on_floor()));
		print("Called at " + Time.get_time_string_from_system() + " | But is it really? " + String(test_move(global_transform, Vector2(0, 5))));
	j = false;
	return;


func _draw() -> void:
	var pos: float = name.length() * (-0.5);
	for letter in name:
# warning-ignore:return_value_discarded
		draw_char(font, Vector2(pos * 16, -20), letter, "");
		pos += 1;

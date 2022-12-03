extends Camera2D


# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"


export (float, 1.0, 10.0) var ZoomRatio = 1.0 setget SetZoom, GetZoom;

func SetZoom(val: float) -> void:
	ZoomRatio = clamp(val, 1, 10);
	zoom = Vector2(1/ZoomRatio, 1/ZoomRatio);
	return;

func GetZoom() -> float:
	return ZoomRatio;


var Moving: bool = false;
var LocalStart: Vector2 = Vector2.ZERO;


func _input(_event: InputEvent) -> void:
	if (Input.is_action_just_pressed("mouse_right")):
		Moving = true;
		LocalStart = get_local_mouse_position();
	elif (Input.is_action_just_released("mouse_right")):
		Moving = false;
	elif (Input.is_mouse_button_pressed(4)):
		SetZoom(ZoomRatio + 0.1);
	elif (Input.is_mouse_button_pressed(5)):
		SetZoom(ZoomRatio - 0.1);
	return;


func _process(delta: float) -> void:
	if Moving:
		global_position -= (get_local_mouse_position() - LocalStart) * delta;
	return;


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass

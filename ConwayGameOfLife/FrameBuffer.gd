extends Sprite


# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"


export var BufferPath: NodePath;
export var UpdateInterval: float = 0;
export var Active: bool = true setget SetActive, GetActive;
export var TextDisplayPath: NodePath;
export var DisplayPath: NodePath;

func GetActive() -> bool:
	return Active

func SetActive(val: bool) -> void:
	Active = val;
	material.set_shader_param("active", Active);
	if Active:
		yield(VisualServer, "frame_post_draw");
		set_texture(BufferViewport.get_texture());
		texture.flags = texture.FLAGS_DEFAULT - 4;
	return;

onready var Display: Sprite = get_node(DisplayPath);
onready var TextDisplay: Label = get_node(TextDisplayPath);
onready var BufferViewport: Viewport = get_node(BufferPath);
var TimeSinceLastUpdate: float = 0;
var c: int = 0;


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Display.texture = get_viewport().get_texture();
	Display.texture.flags = Texture.FLAGS_DEFAULT - 4;
	if TextDisplay != null: TextDisplay.text = "Draw Radius: " + String(DrawRadius);
	yield(get_tree().create_timer(UpdateInterval), "timeout");
	SetActive(Active);
	pass # Replace with function body.


var DotBuffer: PoolVector2Array = [];
export var DrawRadius: int = 1 setget SetDrawRadius, GetDrawRadius;

func GetDrawRadius() -> int:
	return DrawRadius;

func SetDrawRadius(val: int) -> void:
	if val < 1: val = 1;
	DrawRadius = val;
	if TextDisplay != null: TextDisplay.text = "Draw Radius: " + String(DrawRadius);
	yield(VisualServer, "frame_post_draw");
	var txtr: ImageTexture = ImageTexture.new();
	var img: Image = get_viewport().get_texture().get_data();
	img.flip_y();
	txtr.create_from_image(img);
	txtr.flags = Texture.FLAGS_DEFAULT - 4;
	set_texture(txtr);
	DotBuffer.resize(0);
	update();
	return;


func _process(delta: float) -> void:
	if (Input.is_action_just_pressed("ui_accept")):
		yield(VisualServer, "frame_post_draw");
		var txtr: ImageTexture = ImageTexture.new();
		var img: Image = get_viewport().get_texture().get_data();
		img.flip_y();
		txtr.create_from_image(img);
		txtr.flags = Texture.FLAGS_DEFAULT - 4;
		set_texture(txtr);
		DotBuffer.resize(0);
		update();
		SetActive(!Active);
	if Active:
		if UpdateInterval > 0:
			TimeSinceLastUpdate += delta;
			if TimeSinceLastUpdate >= UpdateInterval:
				TimeSinceLastUpdate -= UpdateInterval * floor(TimeSinceLastUpdate/UpdateInterval);
				material.set_shader_param("active", true);
			else:
				material.set_shader_param("active", false);
		else:
			material.set_shader_param("active", true);
	else:
		if Input.is_mouse_button_pressed(1):
			var pos: Vector2 = Display.get_local_mouse_position();
			pos.x = round(pos.x) + (DrawRadius % 2)/2.0;
			pos.y = round(pos.y) + (DrawRadius % 2)/2.0;
			DotBuffer.append(pos);
			update();
		elif (Input.is_action_just_pressed("ui_up")):
			SetDrawRadius(DrawRadius + 1);
		elif (Input.is_action_just_pressed("ui_down")):
			SetDrawRadius(DrawRadius - 1);
	return;

func _draw() -> void:
	for Point in DotBuffer:
		draw_circle(Point, DrawRadius/2.0, Color(1.0, 1.0, 1.0, 1.0));
	return;


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass

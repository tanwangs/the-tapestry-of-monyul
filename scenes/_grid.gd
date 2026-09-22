extends Node2D
## Temporary helper: draws a tile grid over a sheet so the cells are readable.

@export var step: float = 48.0
@export var cols: int = 16
@export var rows: int = 13


func _draw() -> void:
	for c in cols + 1:
		draw_line(Vector2(c * step, 0), Vector2(c * step, rows * step), Color(1, 0.15, 0.15, 0.55), 1.0)
	for r in rows + 1:
		draw_line(Vector2(0, r * step), Vector2(cols * step, r * step), Color(1, 0.15, 0.15, 0.55), 1.0)
extends Node

# --- Gameplay Signals ---
signal dug_tile(pos: Vector2, color: Color)
signal moved_freely(pos: Vector2)
signal hit_wall(pos: Vector2)
signal hit_rock(pos: Vector2)
signal hit_mine(pos: Vector2)
signal collected_battery(pos: Vector2)
signal collected_gold(pos: Vector2)
signal collected_diamond(pos: Vector2)
signal placed_bomb(pos: Vector2)
signal detonated_bomb(pos: Vector2)
signal low_battery_warning(is_low: bool)
signal battery_depleted(pos: Vector2)
signal frenzy_tier_changed(tier: int)
signal vehicle_movement_updated(is_moving: bool, current_speed: float)

# --- UI & Meta Signals ---
signal ui_button_clicked()
signal ui_button_hovered()
signal scene_changed(scene_name: String)

# Shatter-Drill: Implemented Features Log

This document logs all the features, logic, and polish implemented during this development session for the **Shatter-Drill** arcade prototype.

---

## 🚀 Core Systems

### 1. Grid-Locked Movement & Digging
- **Grid Size & Snap:** All coordinates snaped to a 16px grid.
- **Directional Digging:**
  - **Down:** Costs **1.0 battery**, slows movement to drilling speed.
  - **Horizontal/Up:** Costs **0.5 battery**, slows movement to drilling speed.
  - **Free Space:** Costs **0.0 battery**, runs at quick free movement speed.

### 2. Battery & Recharge System
- **Recharge Tiles:** Battery recharge canister tiles (sprite coordinates `(47, 9)`) spawned in the dirt layout.
- **Recharging:** Landing on a recharge tile automatically erases it and restores **3.0 shards** of battery (capped at 10.0). No battery is consumed for the step.

### 4. Bomb & Pickup System
- **Bomb Pickups:** Bomb canister tiles (sprite coordinates `(45, 9)`) spawned in the grid layout. Collecting one restores **1 bomb** (capped at 3).
- **Placement & Fuse:** Pressing `ui_accept` (Space) consumes **3.0 battery** and **1 bomb** to plant an explosive on the current tile. The bomb ticks down on a **2.0-second fuse** while flashing red/white.
- **3x3 Blast Radius:** Obliterates all breakable tiles and items in a 3x3 area around the bomb's origin. Indestructible side walls are immune.
- **Blast Penalty:** Standing inside the 3x3 blast area when it detonates deals a **5.0 battery damage penalty** to the player.

### 5. Undiggable Tiles System
- **Hard Obstacles:** Undiggable tiles (sprite coordinates `(39, 15)`) block regular drilling attempts.
- **Drill Response:** Drilling into an undiggable tile blocks movement, resets combo, emits `hit_wall` feedback (camera shake and sound effect), and consumes **0 battery**.
- **Bomb Destructible:** Unlike perimeter walls, undiggable tiles **can** be destroyed using bombs.

### 6. Bomb Inventory HUD UI
- **Visuals:** Shows 3 square red indicators directly below the battery container.
- **Dynamic State:** Squares transition from Bright Red (available) to Dark Grey (empty) as bombs are used or picked up.

---

## 🎮 Game Feel & "Juice"

### 1. Digging Resistance
- **Dynamic Friction:** Movement through free space is fast and snappy (`MOVE_SPEED_FREE = 160.0`, ~0.1s per cell). Movement when drilling or collecting rechargeable tiles is slowed down (`MOVE_SPEED_DIRT = 53.0`, ~0.3s per cell) to give a heavy, tactile feel.

### 2. Decoupled Feedback System
- **Observer Pattern:** The `Player` script emits signals (`dug_tile`, `moved_freely`, `hit_wall`, `collected_battery`, `placed_bomb`, `detonated_bomb`) but handles no sound or particle assets.
- **FeedbackManager Node:** A dedicated `FeedbackManager` node intercepts these signals to trigger VFX and SFX.
- **Inspector Tuning:** Exposes `@export` variables for `PackedScene` (VFX) and `AudioStream` (SFX) so sounds and particle systems can be swapped directly inside the Godot Editor inspector.

### 3. Drill Jitter / Vibration
- **Visuals:** While drilling through a cell, the player's `Sprite2D` is offset randomly by 1.5 pixels in all directions on every frame. Snaps back to `(0,0)` center upon finishing the move. Makes the vehicle look like it's grinding hard.

### 4. Shard Shatter Particles
- **Explosion:** When a tile is dug (or a battery is collected), the `FeedbackManager` spawns 8 tiny square fragments (size 2-4px) matching the tile color.
- **Gravity:** Shards blow out in random directions and fall downward due to simulated gravity, rolling off the viewport.

### 5. Crisp Camera & Wall Hit Shake
- **Camera Configuration:** Viewport is scaled up 4x using a `Camera2D` with boundaries limiting horizontal view within play bounds. Crisp smoothing (`position_smoothing_speed = 8.0`) enabled.
- **Noise Shake:** Attacking or hitting a wall/boundary triggers a smooth 6.0px screen shake, powered by a custom `FastNoiseLite` generator that decays linearly.

### 6. Combo System
- **Arcade Indicator:** A `COMBO xN` label sits on the HUD.
- **Rules:** Increments with consecutive block digests (including battery collections). Resets to `0` instantly if the player stops moving (idles), moves into an empty tile, or bumps a wall.
- **Bounce Juice:** Tweened scale-punch visual bounce occurs on each increment.

### 7. Exaggerated Bomb Juice
- **Bomb Drop Bounce:** When planted, the bomb sprite scales up dynamically from `0.1` to `1.5` before bouncing back down to `1.0` for a punchy, tactile feel. Emits a `"Deep Thud (Bomb Placed)"` SFX signal.
- **Bomb Detonation Explosion:** Spawns 30 high-velocity orange/red particles with gravity, triggers a massive `10.0px` camera shake, and logs a `"Loud Boom (Explosion)"` SFX.

---

## 🛠️ Developer & Playtest Utilities
- **Infinite Battery Toggle:** Exposes an `@export var infinite_battery: bool` checkbox in the Player Inspector. Enabling it stops battery consumption for easy drilling testing.

---

## 📂 File Architecture

- **Player Logic:** [Player.gd](file:///f:/Godot/Projects/digger-kill-games/scenes/MainLevel/Player.gd)
- **Grid Dirt Logic:** [DiggableLayer.gd](file:///f:/Godot/Projects/digger-kill-games/scenes/MainLevel/DiggableLayer.gd)
- **Fractional Shard UI & Bomb HUD:** [HUD.gd](file:///f:/Godot/Projects/digger-kill-games/scenes/MainLevel/HUD.gd)
- **VFX/SFX Manager:** [FeedbackManager.gd](file:///f:/Godot/Projects/digger-kill-games/scenes/MainLevel/FeedbackManager.gd)
- **Noise Camera Shake:** [PlayerCamera.gd](file:///f:/Godot/Projects/digger-kill-games/scenes/MainLevel/PlayerCamera.gd)
- **Main Scene:** [MainLevel.tscn](file:///f:/Godot/Projects/digger-kill-games/scenes/MainLevel/MainLevel.tscn)

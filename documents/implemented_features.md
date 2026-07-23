# Shatter-Drill: Implemented Features Log

This document logs all the features, logic, and polish implemented during this development session for the **Shatter-Drill** arcade prototype.

---

## 🚀 Core Systems

### 0. Startup Procedural Map Generation
- **Level Dimensions:** 10 playable columns (columns 1 to 10) x 500 rows deep, framed by indestructible side border walls (`col 0` and `col 11`) and a metallic floor (`row 499`).
- **Surface Onboarding Zone:** Rows 0 to 3 are cleared of tiles to guarantee safe vehicle spawning and controls familiarization.
- **3-Biome Progression:**
  - **Biome 1 (Normal Soil - Depth 4 to 150):** 85% Soft Dirt, 5% Rock, 5% Battery Canisters, 5% Bomb Canisters.
  - **Biome 2 (Rocky Layer - Depth 151 to 350):** 60% Soft Dirt, 25% 3-Hit Rock, 8% Battery Canisters, 7% Bomb Canisters.
  - **Biome 3 (Ancient Mines - Depth 351 to 498):** 45% Soft Dirt, 30% Rock, 15% Undiggable Wall Blocks, 5% Battery, 5% Bomb.
- **Guaranteed Battery Spawning:** Enforces a safety rule spawning at least 1 battery canister every 8-12 depth rows to eliminate unwinnable drought bottlenecks.
- **Seed Configuration:** Exposes `@export var seed_value: int = 0` (`0` = randomized on boot; non-zero = reproducible seed).

### 0.1 Depth & Layer Tracker UI
- **Real-Time Depth Signal:** Emits `depth_changed(current_depth: int, biome_name: String)` from `Player.gd` as the vehicle drills vertically into new grid rows.
- **HUD Biome Display:** Top-right anchored `_layer_label` displays current depth in meters and active biome name (e.g. `📍 DEPTH: 42m | Layer 1: Normal Soil`).
- **Biome Transition Punch:** Plays a spring scale-punch animation when transitioning into a new biome layer (Surface -> Layer 1 -> Layer 2 -> Layer 3).

### 0.2 SilentWolf REST API Online Leaderboard & SKG Fallback
- **Online Integration (`SilentWolf REST API`):** Asynchronously posts and fetches global scores using native Godot `HTTPRequest` nodes configured for game `digger` (no external plugin/addon required).
- **Hybrid SKG Local Persistence (`user://local_leaderboard.cfg`):** Every score submission is written to local hardware *first* before making the API request. If network connection fails or server is offline, the game automatically displays local high scores tagged as `--- LOCAL SKG LEADERBOARD (OFFLINE) ---`.
- **Run Score Calculation:** Combined Score metric: `(Max Depth * 10) + Total Wealth Collected`.
- **Game Over Overlay Modal:** Automatically pops up on `CanvasLayer` 1.2s after battery depletion with pop-in animation, displaying stats summary, name LineEdit input, "Submit Score" button, dynamic top 10 leaderboard table with online/offline indicator, and a "Play Again" restart button.

### 1. Grid-Locked Movement & Digging
- **Grid Size & Snap:** All coordinates snaped to a 16px grid.
- **Directional Digging:**
  - **Down:** Costs **1.0 battery**, slows movement to drilling speed.
  - **Horizontal/Up:** Costs **0.5 battery**, slows movement to drilling speed.
  - **Free Space:** Costs **0.0 battery**, runs at quick free movement speed.

### 2. Battery & Recharge System
- **Recharge Tiles:** Battery recharge canister tiles (sprite coordinates `(47, 9)`) spawned in the dirt layout.
- **Recharging:** Landing on a recharge tile automatically erases it and restores **3.0 shards** of battery (capped at 10.0). No battery is consumed for the step.
- **⚠️ Enhanced Low-Battery Warning System ($\le 3.0$ Shards / $30\%$ Capacity):**
  - **Screen Edge Red Vignette:** A soft pulsing red edge overlay pulses across the screen while in low battery state.
  - **Floating Vehicle Warning Icon:** A bold `⚠️ LOW BAT` flashing text label floats directly above the player vehicle sprite.
  - **HUD Container Scale Punch:** `$BatteryContainer` pops up $1.25\times$ with scale-punch spring animation when warning triggers, while remaining filled shards pulse gold/red.
  - **Step-by-Step Sputter Sparks & SFX:** Emits electric yellow sparks and dark smoke particle puffs on every dig step along with sputtering engine audio logs.
- **🛑 Battery Depletion Breakdown Sequence ($0.0$ Battery):**
  - **1.0s Multi-Stage Power-Down:** Player movement locks instantly upon depletion.
  - **Engine Stall & Sparks:** Vehicle sprite stutters/shakes, squashes/stretches, and dims to an unpowered dark grey tint (`#40404c`).
  - **Spark & Smoke Burst:** Emits rising heavy dark smoke clouds and electric cyan spark explosions (`CPUParticles2D`).
  - **Camera Noise Shake:** Triggers an $8.0\text{px}$ camera noise shake and plays a power-down pitch-drop sound.
  - **Arcade Banner:** Displays a bold `⚠️ BATTERY EXHAUSTED! ⚠️` HUD banner with scale-punch animation and red/yellow warning flashes.

### 4. Bomb & Pickup System
- **Bomb Pickups:** Bomb canister tiles (sprite coordinates `(45, 9)`) spawned in the grid layout. Collecting one restores **1 bomb** (capped at 3).
- **On-The-Move Placement:** Pressing `ui_accept` (Space) consumes **3.0 battery** and **1 bomb** to plant an explosive on the current grid tile center (`snapped(16, 16) + (8, 8)`) **without stopping vehicle movement**.
- **Fuse Timer:** The bomb ticks down on a **2.0-second fuse** while flashing red/white with a bouncy drop pop.
- **3x3 Blast Radius:** Obliterates all breakable tiles and items in a 3x3 area around the bomb's origin. Indestructible side walls are immune.
- **Blast Penalty:** Standing inside the 3x3 blast area when it detonates deals a **5.0 battery damage penalty** to the player.

### 5. Undiggable Tiles & Wall Boundaries System
- **Hard Obstacles:** Undiggable tiles (sprite coordinates `(39, 15)`), perimeter walls, and map boundaries block player movement.
- **Unified 0.3s Impact Cooldown:**
  - Bumping an undiggable tile or wall boundary instantly resets combo and emits `hit_wall` feedback (camera shake & metallic clink SFX).
  - Enforces a standardized **0.3-second input cooldown** via `_trigger_wall_hit()`, matching the Rocky Tile hit rhythm.
  - Holding down a directional key against any wall plays a clean, satisfying 0.3s rhythmic bump without audio or screen-shake spam.
- **Bomb Destructible:** Undiggable tiles **can** be destroyed using bombs (unlike perimeter map edge walls).

### 6. Rocky Tiles System
- **3-Hit Durability Progression:** Rocky tiles (sprite coordinates `(10, 17)`) require **3 hits** total to break through.
- **Instant Hit + 0.3s Cooldown:**
  - Tile damage, battery deduction, 4.0px screen shake, dark grey stone particles, and SFX trigger **instantly on touch**.
  - A dedicated `_is_busy` state lock enforces a clean **0.3-second input cooldown** between hits.
  - Holding down a directional key against rock takes **~0.9 seconds total** across all 3 hits with smooth input pacing and zero input buffering bugs.
- **Hit Progression:**
  - **1st Hit (`10, 17`):** Instant rock hit feedback $\rightarrow$ transforms tile into Cracked Rock (`11, 17`) $\rightarrow$ 0.3s cooldown.
  - **2nd Hit (`11, 17`):** Instant rock hit feedback $\rightarrow$ transforms tile into Standard Dirt (`32, 15`) $\rightarrow$ 0.3s cooldown.
  - **3rd Hit (`32, 15`):** Digs standard dirt normally, spending battery and stepping forward into the cell.
- **Bomb Destruction:** Bombs obliterate rocky tiles in **1 hit** regardless of damage stage.

### 7. Bomb Inventory HUD UI
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

### 6. Arcade Combo & 5-Tier Frenzy System
- **Arcade Indicator:** A `COMBO xN` label sits on the HUD.
- **Rules:** Increments with consecutive block digests (including battery collections). Resets to `0` instantly if the player stops moving (idles), moves into an empty tile, or bumps a wall.
- **Bounce Juice:** Tweened scale-punch visual bounce occurs on each increment.
- **🌟 REVISED 5-TIER FRENZY ESCALATION:**
  - **Level 1 (COMBO x10 - Cyan):** 0 Battery Drain + **Slight Speed Boost (`85.0`)**.
  - **Level 2 (COMBO x20 - Gold):** 0 Battery Drain + **More Speed Boost (`120.0`)**.
  - **Level 3 (COMBO x30 - Green):** Adds **Battery Recharge** (+0.5 battery restored on every step dug).
  - **Level 4 (COMBO x40 - Orange):** Adds **Side Micro-Shockwave** (clears 2 perpendicular side soft dirt tiles, leaving the front tile intact so the combo streak is never broken).
  - **Level 5 (COMBO x50 - Magenta):** **HYPER GOD DRILL!** Max speed `160.0`, 1-hit rocks, and full battery (10.0) + bomb (+3) refill!
  - **Undiggable Protection:** Undiggable tiles (`39, 15`) and perimeter walls **always** block drilling across all levels, preserving layout structure and bomb utility.

### 8. Directional Lunge & Squash/Stretch Hit Animation
- **Universal Physical Juice:** Applied across all dirt digs, rock hits, undiggable bumps, and wall boundary impacts via `_play_impact_lunge(dir)`.
- **Directional Lunge:** Vehicle sprite lunges **4px** into the direction of impact (`dir * 4.0`) over 0.05s.
- **Squash & Stretch:** Squishes scale to `(1.25, 0.75)` for horizontal hits or `(0.75, 1.25)` for vertical hits.
- **Spring Recoil:** Springs back to `Vector2.ZERO` offset and `Vector2.ONE` scale over 0.12s with `TRANS_SPRING` easing, ensuring the vehicle never looks static during consecutive hits or digging steps.

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

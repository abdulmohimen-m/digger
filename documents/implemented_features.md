# Shatter-Drill: Implemented Features Log

This document logs all the features, logic, and polish implemented during this development session for the **Shatter-Drill** arcade prototype.

---

## 🚀 Core Systems

### 0. Startup Procedural Map Generation
- **Level Dimensions:** 10 playable columns (columns 1 to 10) x 500 rows deep, framed by indestructible side border walls (`col 0` and `col 11`) and a metallic floor (`row 499`).
- **Surface Onboarding Zone:** Rows 0 to 3 are cleared of tiles to guarantee safe vehicle spawning and controls familiarization.
- **3-Biome Progression:**
  - **Biome 1 (Normal Soil - Depth 4 to 150):** Soft Dirt base with 3% Undiggable, 5% Rock, 5% Battery, 5% Bomb, 4% Mine, and 1.5% scattered gems.
  - **Biome 2 (Rocky Layer - Depth 151 to 350):** Soft Dirt base with 8% Undiggable, 25% 3-Hit Rock, 5% Battery, 6% Bomb, 6% Mine, and 3% scattered gems.
  - **Biome 3 (Ancient Mines - Depth 351 to 498):** Soft Dirt base with 15% Undiggable, 25% Rock, 5% Battery, 5% Bomb, 10% Mine, and 5% scattered gems.
- **Bedrock Strata System (Forced Pathing):** Generates horizontal solid floors of `TILE_UNDIGGABLE` metal every 15-25 depth rows (starting past depth 20) with 1 or 2 narrow gaps (`TILE_DIRT`). Forces players to move horizontally to locate openings, breaking predictable vertical rushing. Includes pre-stratum row safety (zero undiggables on row above) and automatically reroutes forced battery spawns into stratum gaps.
- **Procedural Horizontal Vein System:** 15% of all rows generate contiguous 3-to-5 tile wide horizontal resource veins (`TILE_GOLD` and `TILE_DIAMOND`), concentrating collectible wealth into horizontal clusters to heavily incentivize side exploration. Biome depth scales diamond vein ratio (10% in Biome 1 $\rightarrow$ 35% in Biome 2 $\rightarrow$ 55% in Biome 3).
- **Guaranteed Battery Spawning:** Enforces a safety rule spawning at least 1 battery canister every 8-12 depth rows to eliminate unwinnable drought bottlenecks.
- **Seed Configuration:** Exposes `@export var seed_value: int = 0` (`0` = randomized on boot; non-zero = reproducible seed).

### 0.1 Depth & Layer Tracker UI
- **Real-Time Depth Signal:** Emits `depth_changed(current_depth: int, biome_name: String)` from `Player.gd` as the vehicle drills vertically into new grid rows.
- **HUD Biome Display:** Top-right anchored `_layer_label` displays current depth in meters and active biome name (e.g. `📍 DEPTH: 42m | Layer 1: Normal Soil`).
- **Biome Transition Punch:** Plays a spring scale-punch animation when transitioning into a new biome layer (Surface -> Layer 1 -> Layer 2 -> Layer 3).

### 0.2 SilentWolf REST API Online Leaderboard & SKG Fallback
- **Online Integration (`SilentWolf REST API`):** Asynchronously posts and fetches global scores using native Godot `HTTPRequest` nodes configured for game `digger` (no external plugin/addon required).
- **Hybrid SKG Local Persistence (`user://local_leaderboard.cfg`):** Every score submission is written to local hardware *first* before making the API request. If network connection fails or server is offline, the game automatically displays local high scores tagged as `--- LOCAL SKG LEADERBOARD (OFFLINE) ---`.
- **Top 50 Score Capacity:** Extended leaderboard tracking capacity from 10 to 50 entries across online SilentWolf and local SKG persistence.
- **Player Rank Highlighting & Glowing Box:** Identifies the player's submitted score row and wraps it in a distinct glowing cyan panel box (`#005973` bg with `#00e5ff` border), gold text, and a `👉 #Rank Name - Score (YOU) 👈` indicator tag with pulsing border animations.
- **Contextual Out-Of-Top-10 Ranking:** If the player's score ranks outside the Top 10 (e.g., rank #24 out of 50), the table renders Top 3 scores $\rightarrow$ `...` divider $\rightarrow$ player's rank context (rank - 1, player rank [YOU], rank + 1) so their exact standing is always visible.
- **Smooth Auto-Scroll Centering:** Automatically animates `ScrollContainer.scroll_vertical` with a spring tween to center on the player's rank panel box when scores load.
- **Multicultural Default Miner Names:** Pre-populates the score submission input with 50 multicultural digging/mining titles (e.g., `Hafir`, `Kopacz`, `Bergmann`, `Madenci`, `Khanak`, `Gornik`, `Minero`, `Tunneller`) combined with a random 4-digit number between `1000` and `9999` (e.g. `Kopacz4819`, `Madenci8291`, `Hafir1042`).
- **Run Score Calculation:** Combined Score metric: `(Max Depth * 10) + (Gold * 100) + (Diamonds * 300)`.
- **Game Over Overlay Modal:** Automatically pops up on `CanvasLayer` 1.2s after battery depletion with pop-in animation, displaying stats summary, name LineEdit input, "Submit Score" button, dynamic top 10 leaderboard table with online/offline indicator, and a "Play Again" restart button.

### 1. Grid-Locked Movement & Digging
- **Grid Size & Snap:** All coordinates snaped to a 16px grid.
- **Directional Digging:**
  - **Down:** Costs **1.0 battery**, slows movement to drilling speed.
  - **Horizontal/Up:** Costs **0.5 battery**, slows movement to drilling speed.
  - **Free Space:** Costs **0.0 battery**, runs at quick free movement speed.

  - **1.0s Multi-Stage Power-Down:** Player movement locks instantly upon depletion.
  - **Engine Stall & Sparks:** Vehicle sprite stutters/shakes, squashes/stretches, and dims to an unpowered dark grey tint (`#40404c`).
  - **Spark & Smoke Burst:** Emits rising heavy dark smoke clouds and electric cyan spark explosions (`CPUParticles2D`).
  - **Camera Noise Shake:** Triggers an $8.0\text{px}$ camera noise shake and plays a power-down pitch-drop sound.
  - **Arcade Banner:** Displays a bold `⚠️ BATTERY EXHAUSTED! ⚠️` HUD banner with scale-punch animation and red/yellow warning flashes.

### 4. 💣 Bomb & Remote Detonation System
- **Bomb Pickups:** Bomb canister tiles (`6, 0`) spawned in the grid layout restore **1 bomb** when collected (capped at 3).
- **On-The-Move Placement:** Pressing `ui_accept` (Space) when no bomb is active consumes **3.0 battery** and **1 bomb** to plant an explosive on the current grid cell.
- **⚡ Remote Detonation Controls:** Pressing `ui_accept` (Space) while a bomb is ticking on the map **instantly detonates all active bombs** remotely at zero battery cost!
- **💥 4-Way Cross-Blast Wave (+ Pattern):**
  - **⚡ Step-by-Step Shockwave Propagation (0.04s per Ring):** Blast waves expand outward ring by ring (Center $\rightarrow$ Ring 1 $\rightarrow \dots \rightarrow$ Ring 6) over ~0.24 seconds total.
  - **🔥 Synchronous Fire Pillar Step Wave:** **Horizontal Fire Pillars (`7,2`)** and **Vertical Fire Pillars (`7,3`)** pop up in sequence ring-by-ring with 1.35x scale punch & 0.25s fade as the wave front propagates.
  - Synchronously clears soft soil, rock blocks, metal blocks, and mine hazards while stopping at indestructible outer map borders.
  - Instantly shatters falling/wobbling rocks caught in the blast path.
- **🔊 Dynamic Motor Drill Pitch Scaling:**
  - **Slow Dirt Digging & Plain Tile Movement:** Plays at **1.60x pitch** for consistent motor feedback.
  - **Frenzy Super-Drilling Speeds:** Scales higher dynamically between **1.80x and 2.40x pitch** as digging speed ramps up during high combo combos.
- **Self-Damage Penalty:** Standing in any cell of the cross-blast wave deals a **5.0 battery damage penalty**.

### 5. Undiggable Tiles & Wall Boundaries System
- **Hard Obstacles:** Undiggable metal tiles (sprite coordinates `(4, 0)`), perimeter walls `(0, 0)`, and map boundaries block player movement.
- **Multi-Biome Progression:** Introduced from the first level with progressive density scaling:
  - **Biome 1 (Normal Soil):** 3% Low Density (introduces navigational hazard early).
  - **Biome 2 (Rocky Soil):** 8% Medium Density.
  - **Biome 3 (Ancient Mines):** 15% High Density.
- **Unified 0.3s Impact Cooldown:**
  - Bumping an undiggable tile or wall boundary instantly resets combo and emits `hit_wall` feedback (camera shake & metallic clink SFX).
  - Enforces a standardized **0.3-second input cooldown** via `_trigger_wall_hit()`, matching the Rocky Tile hit rhythm.
  - Holding down a directional key against any wall plays a clean, satisfying 0.3s rhythmic bump without audio or screen-shake spam.
- **Bomb Destructible:** Undiggable metal blocks **can** be destroyed using bombs (unlike perimeter map edge walls).

### 6. Rocky Tiles System
- **3-Hit Durability Progression:** Rocky tiles (sprite coordinates `(2, 0)`) require **3 hits** total to break through.
- **Instant Hit + 0.3s Cooldown:**
  - Tile damage, battery deduction, 4.0px screen shake, dark grey stone particles, and SFX trigger **instantly on touch**.
  - A dedicated `_is_busy` state lock enforces a clean **0.3-second input cooldown** between hits.
  - Holding down a directional key against rock takes **~0.9 seconds total** across all 3 hits with smooth input pacing and zero input buffering bugs.
- **Hit Progression:**
  - **1st Hit (`2, 0`):** Instant rock hit feedback $\rightarrow$ transforms tile into Cracked Rock (`1, 0`) $\rightarrow$ 0.3s cooldown.
  - **2nd Hit (`1, 0`):** Instant rock hit feedback $\rightarrow$ transforms tile into Standard Dirt (`5, 0`) $\rightarrow$ 0.3s cooldown.
  - **3rd Hit (`5, 0`):** Digs standard dirt normally, spending battery and stepping forward into the cell.
- **Bomb Destruction:** Bombs obliterate rocky tiles in **1 hit** regardless of damage stage.

### 7. Bomb Inventory HUD UI
- **Visuals:** Shows 3 square red indicators directly below the battery container.

### 8. Mine Hazards System
- **Subtle Tile Signpost:** Mine tiles (atlas coordinate `(3, 0)`) spawn with subtle dirt-like signposting across all biomes (4% Biome 1, 6% Biome 2, 10% Biome 3).
- **Instant Explosion & Battery Damage:** Digging or stepping on a mine triggers an instant explosion, deducting a **4.0 battery penalty**, resetting the combo, erasing the tile, and emitting a heavy 12.0px camera shake and fiery red/orange particle explosion (`hit_mine` signal).
- **Bomb Clearing:** Player bombs safely obliterate mine tiles in their 3x3 blast radius without triggering penalties.
- **Frenzy Immunity:** Reaching Frenzy Mode (combo streak $\ge 10$) allows the drilling vehicle to blast safely through mines with 0 battery cost.

### 9. Gold & Diamond Collectibles System
- **Vein-Based & Progressive Biome Rarity:** Gold Veins (`4, 1`) and Diamond Ores (`3, 1`) now primarily spawn in horizontal 3-to-5 block contiguous veins (15% row chance), supplemented by minor scattered deposits (1-3%). Diamond ratio scales with depth (Biome 1: 10% Diamond / 90% Gold, Biome 2: 35% Diamond / 65% Gold, Biome 3: 55% Diamond / 45% Gold).
- **Dedicated HUD Counters:** Displays real-time item collection counts on dedicated HUD labels: `🟡 GOLD: N` (gold) and `💎 DIAMOND: N` (cyan) with scale-punch spring bounce animations.
- **Score Calculation Integration:** Final run score formula: `(Max Depth * 10) + (Gold * 100) + (Diamonds * 300)`.
- **Bomb Auto-Collection:** Detonating a bomb in a 3x3 area automatically collects any Gold and Diamond tiles caught in the blast area without destroying their value.
- **Juice & Floating Popups:** Digging a Gold or Diamond tile triggers glowing floating text popups (`+100` gold / `+300` cyan), particle explosions matching item colors, and chime SFX.
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
- **Arcade Indicator:** A `COMBO xN` label sits on the HUD with an animated gold/red draining progress bar underneath.
- **🌟 REVISED 1.5s COMBO DECAY WINDOW:**
  - Idling or moving through empty space no longer resets the combo streak immediately.
  - A **1.5-second combo decay timer** starts, visually draining the HUD meter bar.
  - Digging any valid tile before 1.5s expires resets the timer to 100% and increments the combo count.
  - Bumping an undiggable wall or hitting a mine hazard bypasses the 1.5s timer and resets the combo instantly.
- **Bounce Juice:** Tweened scale-punch visual bounce occurs on each increment.
- **🌟 5-TIER FRENZY ESCALATION:**
  - **Level 1 (COMBO x10 - Cyan):** 0 Battery Drain + **Slight Speed Boost (`85.0`)** + Mine Explosion Immunity.
  - **Level 2 (COMBO x20 - Gold):** 0 Battery Drain + **More Speed Boost (`120.0`)**.
  - **Level 3 (COMBO x30 - Green):** Adds **Battery Recharge** (+0.5 battery restored on every step dug).
  - **Level 4 (COMBO x40 - Orange):** Adds **Side Micro-Shockwave** (clears 2 perpendicular side soft dirt tiles).
  - **Level 5 (COMBO x50 - Magenta):** **HYPER GOD DRILL!** Max speed `160.0`, 1-hit rocks, and full battery (10.0) + bomb (+3) refill!
  - **Undiggable Protection:** Undiggable tiles and perimeter walls always block drilling across all levels.

### 7. 🪨 Falling Rock Gravity Physics System
- **0.4s/0.7s Wobble Telegraph:** Digging, blasting, or clearing a tile beneath any Rock block (`TILE_ROCK` or `TILE_CRACKED_ROCK`) triggers a **0.7-second wobble state** with particle dust emissions and camera jitter.
- **Medium-Slow Gravity Fall:** If space beneath remains empty after wobble ends, the rock falls vertically downward at ~2.8 tiles/sec (`0.35s` step timer), providing a readable reaction window to step aside.
- **💥 Overhauled Player Crush Juice & Visual Feedback:**
  - **Extreme Pancake Vehicle Squish:** Vehicle sprite flattens to **2.0x width** and **0.2x height** (+6px Y ground offset) and flashes crimson (`Color(2.5, 0.2, 0.2)`).
  - **0.20s Hold Delay:** Holds the flattened pancake shape for 200ms so the squish is unmistakably visible before springing back over 0.25s.
  - **20 Stone Fragments + 10 Dust Particles:** Explode outward and upward from the vehicle hull.
  - **🔴 Red Screen Impact Flash & 14px Camera Shake:** Full-screen red overlay flashes at 55% opacity with 14px camera shake (text popup removed).
- **Selective Heavy Gravity Rule:** Soil, Gold, Diamonds, and Bombs remain anchored in place so vertical digging shafts don't cause unwanted cave-ins. Boulders/Rocks remain distinct tactical hazards.

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

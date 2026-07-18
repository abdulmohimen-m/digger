# Shatter-Drill: Game Design Document & SKG Jam 2026 Implementation Guide

This comprehensive document outlines the consumer advocacy background of the **Stop Killing Games** movement, analyzes the **SKG Jam 2026**, details the **Shatter-Drill** production-ready Game Design Document (GDD), and provides an optimized technical implementation roadmap for **Godot 4.6**.

---

## Part 1: The "Stop Killing Games" Movement & SKG Jam 2026

### 1.1 What is the Movement?
Launched in 2024 by consumer advocate Ross Scott (*Accursed Farms*), the **Stop Killing Games (SKG)** initiative is a global consumer rights push reacting to publishers destroying digital goods. The catalyst was Ubisoft's shutdown of *The Crew*, which rendered a purchased product unplayable despite it having massive single-player capabilities. 

The core philosophy states that **digital ownership must mean permanent access**. When a publisher stops supporting a game, they should not be allowed to actively break it or lock users out of the software they bought.

### 1.2 Core Goals of the Movement
*   **Functional Longevity:** Forcing publishers to leave retired games in a reasonably functional, playable offline or self-hosted state.
*   **End of "Planned Obsolescence":** Encouraging design systems that do not hard-depend on central, proprietary servers (e.g., providing LAN play, offline patches, or public server binaries).
*   **Legal & Legislative Precedent:** Actively leveraging consumer protection laws, petitions, and initiatives (such as the European Citizens' Initiative) to mandate software preservation.

### 1.3 The SKG Jam 2026 & The "High Score Chasers" Theme
The **SKG Jam 2026** is a community-driven initiative on itch.io designed to prove that future-proof, resilient game architecture is achievable at any scale—even within an indie game jam context. 

*   **The Theme:** `"High Score Chasers"`
*   **The Design Challenge:** Traditionally, high-score games lean on central, live-service databases for competitive validation. If those servers disappear, the "chase" dies. This theme forces jammers to ask: *How do we keep the competitive, community-driven spirit of a high-score chase alive without relying on a central server that could be shut down?*
*   **The Critical Evaluation Criterion:** **"End-of-Life Plan"**. Submissions are strictly judged on how compliant they are with the SKG postulates. The software must be designed from day one to preserve player achievements and gameplay loop mechanics permanently on the player's own hardware.

---

## Part 2: "Shatter-Drill" Game Design Document (GDD)

Shatter-Drill is a highly focused, risk-reward arcade digging game designed to fulfill all **Primary (Green) Priorities** from the game design mind map within a rigorous 48-hour development timeline.

### 2.1 Core Loop & Verbs
```
  [ Move ] -------> [ Dig ]
     ^                 |
     |                 v
 [ Upgrade ] <---- [ Collect ]
```
*   **Move:** Horizontal or vertical grid-locked movement (No diagonal movement to guarantee clean tile-bounding math and prevent collision bugs).
*   **Dig:** Removing a tile immediately adjacent to the drilling vehicle.
*   **Collect:** Automatically vacuuming up gold, diamonds, and battery fuel cells from destroyed tiles.
*   **Upgrade:** Spending collected wealth during the end-of-run state to scale up maximum battery capacity, drilling speed, and bomb efficiency.

### 2.2 Game Structure & Systems
*   **Rules:**
    *   Digging consumes battery power.
    *   Digging straight down consumes significantly more battery than horizontal digging, creating tactical choice.
    *   The game ends instantly when the battery reaches zero.
    *   Bombs consume a heavy burst of battery but instantly obliterate a 3x3 tile area.
    *   Unbreakable perimeter walls define the map edge and are completely immune to digging or explosions.
*   **Constraints:**
    *   No diagonal digging.
    *   Hard rocky blocks require multiple hits/more power to break.
    *   Hidden mines consume a chunk of battery power if drilled.
    *   Randomly distributed gold and diamonds provide currency for meta-progression.
    *   The player can climb back upward through empty, cleared space, but cannot travel outside the visible screen boundaries.
*   **Primary Goal:** Dig as deep as safely possible before the battery is fully depleted, maximizing depth and wealth collected to secure a spot on the persistent leaderboard.

### 2.3 Clarity & Visual Language (Sign-Posting)
To guarantee high clarity under jam constraints without spending valuable hours building text-heavy onboarding screens:
*   **Soft Soil Tiles:** Warm, smooth brown textures. Clear indicator of low battery consumption and 1-hit destruction.
*   **Rocky Soil Tiles:** Darker, jagged, heavily cracked gray stone textures. Indicates 2-hit strength and higher battery friction.
*   **Mines Soil Tiles:** Deep slate gray with flashing red danger dots or hazard stripes. Warns the player of explosive risks.
*   **Indestructible Perimeter Walls:** Sleek, rivets-and-steel metallic textures. Provides instant intuitive understanding that no path exists beyond.

### 2.4 Basic Flow (Layered Biomes)
The map transitions systematically down a vertical axis, creating natural game progression:
1.  **Layer 1 (Normal Soil - Depth 0-150):** Generous fuel/battery spawns, soft soil, basic gold veins. Intended for fast player onboarding.
2.  **Layer 2 (Rocky Soil - Depth 151-350):** High density of rocky soil tiles. Mastery of pathing and fuel management becomes essential.
3.  **Layer 3 (Mines Soil - Depth 351+):** High risk, extreme rewards. Dense clusters of diamond blocks guarded by hidden mine tiles.

### 2.5 Juice & Juxtaposition (Feedback Systems)
*   **Digger Mechanics:** Subtle sprite squish-and-stretch on tile impact; persistent smoke/dirt particles spraying backwards while drilling.
*   **Surfaces:** Distinct visual dust bursts and deep crunch SFX when clearing soil vs. metallic clinks when hitting rock.
*   **Collectibles:** Floating glowing text popups indicating currency gained (`+$100`, `+Battery Max`) accompanied by high-register synth chimes.

### 2.6 The 48-Hour Scope Optimization Strategy
To safeguard your timeline, implement these structural shortcuts:
*   **Merged Menu System:** Do not build independent scenes for Main, Upgrade, and Leaderboard menus. Combine them into a single, cohesive **Game Over / Hangar Hub**. When the player dies, the Game Over screen displays their final depth, prompts their name entry for the local board, and features simple buttons to buy character upgrades before clicking "Launch Next Run".
*   **Overlay Onboarding:** Ditch dedicated tutorial levels. Put basic controls cleanly on the main menu background: *[Arrows / WASD] = Move/Dig | [Space] = Detonate Bomb | Watch Your Battery!*

---

## Part 3: Godot 4.6 Technical Implementation Roadmap

Godot 4.6 features an updated tile system that decouples traditional tile layers into dedicated, self-contained nodes. This fits our architecture beautifully.

### 3.1 Node Tree Structure
Set up your primary gameplay scene (`World.tscn`) using this hierarchy:
*   `World` (`Node2D` - Primary Scene Controller)
    *   `BackgroundLayer` (`TileMapLayer` - Used for non-interactable bedrock aesthetics)
    *   `DiggableLayer` (`TileMapLayer` - Houses all breakable soil, rocks, treasures, and hazards)
    *   `Player` (`CharacterBody2D` - Controlled vehicle containing battery logic)
    *   `CanvasLayer` (`UI Canvas` - Renders HUD, and the combined Game Over/Upgrade overlay)

### 3.2 Fast Fixed-Grid Generation Script
Instead of writing complex, bug-prone infinite generation scripts, generate a massive, bounded grid at startup. Generating a $10 	imes 500$ tile grid takes Godot less than 2 milliseconds and establishes a tangible, definitive goal "bottom."

Attach this script to your `DiggableLayer`:

```gdscript
extends TileMapLayer

@export var map_width: int = 10
@export var map_depth: int = 500

# Constants matching the cell atlas coordinates in your Tileset Resource
const TILE_DIRT = Vector2i(0, 0)
const TILE_ROCK = Vector2i(1, 0)
const TILE_MINE = Vector2i(2, 0)
const TILE_GOLD = Vector2i(0, 1)
const TILE_DIAMOND = Vector2i(1, 1)

func _ready() -> void:
    randomize()
    generate_map()

func generate_map() -> void:
    for x in range(map_width):
        for y in range(map_depth):
            # Create a safe, clear starting zone for player spawn at the surface
            if y < 4:
                continue
                
            # Set indestructible side border boundaries
            if x == 0 or x == map_width - 1:
                # Assuming your indestructible wall tile lives at Vector2i(3, 0)
                set_cell(Vector2i(x, y), 0, Vector2i(3, 0))
                continue
                
            var spawn_roll = randf()
            
            # --- BIOME 1: Normal Soil (Layers 4 to 150) ---
            if y < 150:
                if spawn_roll < 0.07:
                    set_cell(Vector2i(x, y), 0, TILE_GOLD)
                elif spawn_roll < 0.10:
                    set_cell(Vector2i(x, y), 0, TILE_ROCK) # Occasional early hard block
                else:
                    set_cell(Vector2i(x, y), 0, TILE_DIRT)
                    
            # --- BIOME 2: Rocky Soil (Layers 151 to 350) ---
            elif y < 350:
                if spawn_roll < 0.25:
                    set_cell(Vector2i(x, y), 0, TILE_ROCK)
                elif spawn_roll < 0.32:
                    set_cell(Vector2i(x, y), 0, TILE_GOLD)
                else:
                    set_cell(Vector2i(x, y), 0, TILE_DIRT)
                    
            # --- BIOME 3: Ancient Mines (Layers 351 to 499) ---
            else:
                if spawn_roll < 0.12:
                    set_cell(Vector2i(x, y), 0, TILE_MINE)
                elif spawn_roll < 0.20:
                    set_cell(Vector2i(x, y), 0, TILE_DIAMOND)
                elif spawn_roll < 0.45:
                    set_cell(Vector2i(x, y), 0, TILE_ROCK)
                else:
                    set_cell(Vector2i(x, y), 0, TILE_DIRT)
                    
        # Set a hard metallic floor at the absolute bottom row
        set_cell(Vector2i(x, map_depth - 1), 0, Vector2i(3, 0))
```

### 3.3 Core Runtime Digging Logic Walkthrough
When the player triggers a directional movement button, run a predictive check before executing character translation:
1.  Calculate target cell: `var target_cell = local_to_map(player.global_position + move_direction * tile_size)`
2.  Query cell type: `var atlas_coords = get_cell_atlas_coords(target_cell)`
3.  Process conditions:
    *   If `atlas_coords == TILE_DIRT`: Deduct base battery, play smash particle emitter, erase cell `erase_cell(target_cell)`, and allow the player to step forward.
    *   If `atlas_coords == TILE_ROCK`: Check cell health metadata or decrement a hit counter. If fully damaged, erase tile and deduct double battery.
    *   If `atlas_coords == TILE_MINE`: Trigger massive battery explosion reduction penalty, play screen shake, and erase tile.

---

## Part 4: Future-Proof, SKG-Compliant Local Leaderboard

To meet the mandatory preservation requirements of the jam, the leaderboard avoids external SQL databases, web servers, or cloud dependencies. It relies completely on the local operating system's application directory via Godot's safe `user://` pathing. It leverages `ConfigFile` processing, writing human-readable `.cfg` configurations that players can natively back up, inspect, or manually transfer.

### 4.1 Leaderboard Manager Script (`Leaderboard.gd`)
Save this script as a Global Autoload (`Singleton`) so it can be safely referenced across your entire code architecture.

```gdscript
extends Node

const SAVE_PATH = "user://local_leaderboard.cfg"
const MAX_BOARD_ENTRIES = 10

# Saves a new score entry and reorganizes the board locally
func register_high_score(player_name: String, final_score: int, final_depth: int) -> void:
    var config = ConfigFile.new()
    var scores_list = []
    
    # Load historical high scores if the configuration file already exists
    if config.load(SAVE_PATH) == OK:
        if config.has_section("Leaderboard"):
            var saved_names = config.get_section_keys("Leaderboard")
            for entry_name in saved_names:
                var entry_data = config.get_value("Leaderboard", entry_name)
                # entry_data format: [score, depth]
                scores_list.append({
                    "name": entry_name,
                    "score": entry_data[0],
                    "depth": entry_data[1]
                })
                
    # Append the fresh run data
    scores_list.append({
        "name": player_name,
        "score": final_score,
        "depth": final_depth
    })
    
    # Sort the array in descending order based on score metric
    scores_list.sort_custom(func(a, b): return a["score"] > b["score"])
    
    # Constrain the listing to top slots to preserve screen layout sizing
    if scores_list.size() > MAX_BOARD_ENTRIES:
        scores_list.resize(MAX_BOARD_ENTRIES)
        
    # Re-initialize configuration data and overwrite the file securely
    config.clear()
    for item in scores_list:
        config.set_value("Leaderboard", item["name"], [item["score"], item["depth"]])
        
    config.save(SAVE_PATH)
    print("SKG Compliant Score successfully preserved at: ", OS.get_user_data_dir())

# Reads configuration data from disk to populate the User Interface
func get_top_scores() -> Array:
    var config = ConfigFile.new()
    var output_array = []
    
    if config.load(SAVE_PATH) != OK:
        return [] # Return safe empty state if file is not yet initialized
        
    if config.has_section("Leaderboard"):
        var saved_names = config.get_section_keys("Leaderboard")
        for entry_name in saved_names:
            var data = config.get_value("Leaderboard", entry_name)
            output_array.append({
                "name": entry_name,
                "score": data[0],
                "depth": data[1]
            })
            
    # Guarantee presentation layer ordering matches leaderboard priority
    output_array.sort_custom(func(a, b): return a["score"] > b["score"])
    return output_array
```

### 4.2 Integration into the UI Scene
When the game ends and the player hits "Submit Score", link the button's signal directly to this execution string:

```gdscript
func _on_submit_button_pressed() -> void:
	var name_input = $NameLineEdit.text.strip_edges()
	if name_input.is_empty():
		name_input = "Anonymous Miner"
		
	# Write directly to user's hardware
    Leaderboard.register_high_score(name_input, GlobalData.current_score, GlobalData.current_depth)
    
    # Refresh the high score list presentation instantly
    populate_leaderboard_display()
```

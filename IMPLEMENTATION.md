# Implementation Guide — The Tapestry of Monyul

> For developers and AI agents who need to understand and extend the existing work. Every section references actual file paths, node names, and script classes from this project.

---

## Table of Contents

1. [Player / Character Scenes](#1-player--character-scenes)
2. [Maps / Terrain](#2-maps--terrain)
3. [Objects / Interactables](#3-objects--interactables)
4. [Dialogue System](#4-dialogue-system)
5. [NPCs](#5-npcs)
6. [Movement](#6-movement)
7. [GameState / Progression Tracking](#7-gamestate--progression-tracking)
8. [Audio / Background Music](#8-audio--background-music)

---

## 1. Player / Character Scenes

### 1.1 Node Tree

**`res://scenes/player.tscn`** — root node is `Player` (`CharacterBody2D`, groups=["player"]):

```
Player (CharacterBody2D) [y_sort_enabled=true]
├── world_camera (Camera2D) [zoom=Vector2(4,4)]
├── lobby_camera (Camera2D)
├── AnimatedSprite2D [y_sort_enabled=true, position=(0,-21)]
└── CollisionShape2D [y_sort_enabled=true, position=(0,-5)]
```

- The `world_camera` has `limit_left=0, limit_top=1, limit_right=1056, limit_bottom=273` and is drag-enabled. It is referenced in `NyeMap._apply_camera_limits()` to clamp the camera on nye maps.
- The `lobby_camera` has no settings and is only present as a node.
- `AnimatedSprite2D` has `frame_progress = 0.54092306` — a fractional value that was intentionally left here (it affects rendering start frame but was not removed from the player unlike the NPC scenes where it was removed to fix Z-order glitches).

### 1.2 Movement Script

**`res://scripts/player.gd`** — `extends CharacterBody2D`

**Key constants:**
- `SPEED: float = 100.0`
- `TALK_RANGE: float = 60.0`

**Input mapping:** The script tries two input action sets in order:
1. `Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")` — built-in Godot UI actions
2. If that returns `Vector2.ZERO`, falls back to `Input.get_vector("move_left", "move_right", "move_up", "move_down")` — custom action names

Both must be defined in the project's Input Map for movement to work.

**Facing direction logic:**
- If `direction.x != 0`: `_facing = "right" if direction.x > 0 else "left"`
- Otherwise: `_facing = "down" if direction.y > 0 else "up"`

**Animation naming convention** (from `_animate()`):
- `"idle_" + suffix` when not moving
- `"walk_" + suffix` when moving
- `suffix` is determined by `_facing`: `"front"` (default/facing down), `"back"` (facing up), `"side"` (facing left/right)
- `flip_h = true` when facing left

**Movement lock during dialogue:**
```gdscript
if DialogueManager.is_active or Global.ui_locked:
    velocity = Vector2.ZERO
    _animate(false)
    move_and_slide()
    return
```
The player's `_physics_process` checks both `DialogueManager.is_active` and `Global.ui_locked` before processing movement. If either is true, velocity is zeroed and `move_and_slide()` is still called (so physics stays consistent) but no movement happens.

**Talk interaction** (`_unhandled_input`):
1. Checks `DrakayWaterInteract._nearest_water()` first (in Drakay Pangtsho)
2. Then checks `NPC._nearest_talkable()` — iterates all nodes in group `"npc"`, finds closest one where `npc.has_talk()` returns true
3. Calls `water.interact()` or `target.interact()` respectively
4. Uses `get_viewport().set_input_as_handled()` to consume the event

**`_nearest_talkable()`** iterates `get_tree().get_nodes_in_group("npc")` and uses `global_position.distance_to(npc.global_position) <= TALK_RANGE`.

### 1.3 Animation Setup

**`res://scenes/player.tscn`** — `AnimatedSprite2D` uses a `SpriteFrames` resource (`SpriteFrames_mbvj8`) with 6 animations, each 6 frames at speed 10.0:

| Animation | Frames | Source |
|---|---|---|
| `idle_back` | 6 | AtlasTexture from `player (1).png` at rows y=0, x=0..240 (step 48) |
| `idle_front` | 6 | AtlasTexture from `player (1).png` at rows y=96 |
| `idle_side` | 6 | AtlasTexture from `player (1).png` at rows y=48 |
| `walk_back` | 6 | AtlasTexture from `player (1).png` at rows y=192 |
| `walk_front` | 6 | AtlasTexture from `player (1).png` at rows y=144 |
| `walk_side` | 6 | AtlasTexture from `player (1).png` at rows y=240 |

The `player (1).png` sprite sheet has frames arranged in a grid: each frame is 48×48 pixels, with rows for each animation direction.

**Player starts** with `_sprite.play("idle_front")` in `_ready()`.

### 1.4 Spritesheet Format

- Source image: `res://assets/sprites/player (1).png` — contains individual frames of the student character
- Each frame is 48×48 pixels
- Frames are referenced via `AtlasTexture` sub-resources with `region` Rect2 values pointing into the source texture
- The SpriteFrames resource wraps these AtlasTextures into named animations
- All other characters (Aum Jomo, Tshomen, Guide) use separate sprite sheet textures (e.g., `aum_jomo_sheet.png`, `tshomen_sheet.png`, `guide_sheet.png`) with their own `SpriteFrames` `.tres` resources

---

## 2. Maps / Terrain

### 2.1 TileMapLayer Setup

All nye maps (`drakay_pangtsho.tscn`, `tak_tsang.tscn`, `jhomo_lhari.tscn`) follow this pattern:

**Ground layer** — `TileMapLayer` node named `"ground"` (no `y_sort_enabled`):
- Uses a `TileSet` resource with multiple `TileSetAtlasSource` entries
- Each source maps to a texture (grass.png, plains.png, rock_tile.png, wooden.png, etc.)
- The `tile_map_data` is a `PackedByteArray` encoding the tile placement
- `tile_set = SubResource("TileSet_...")` references the TileSet

**Props layer** — `TileMapLayer` node named `"props"` (`y_sort_enabled = true`):
- Uses `TileSet_props` resource
- Has `y_sort_enabled = true` so props sort by Y position
- Same `tile_map_data` format as ground

**Clean water overlay** — `TileMapLayer` node named `"CleanWater"` (no `y_sort_enabled`):
- Uses `TileSet_clean_water` resource (single tile: `0:0/0 = 0`)
- Only visible in Drakay Pangtsho after the offering is complete
- Controlled by `DrakayPangtshoQuest._refresh()`: `_clean_water_layer.visible = finished`

### 2.2 TileSet Structure

Each `TileSet` resource contains:
- `sources/0, sources/1, ...` — references to `TileSetAtlasSource` sub-resources
- Each `TileSetAtlasSource` has:
  - `texture = ExtResource(...)` — the source image
  - Tile entries like `0:0/0 = 0`, `0:0/0/y_sort_origin = 14`, etc.
  - Optional `physics_layer_0/polygon_0/points` for collision shapes

**Source conventions across maps:**
- `TileSet_lh53h` (Drakay Pangtsho): grass.png (source 0), plains.png (source 1), water_tile.png (source 2) — 3 sources
- `TileSet_i4whv` (Taktsang): grass.png (source 0), rock_tile.png (source 1), wooden.png (source 2), objects.png (source 3) — 4 sources
- `TileSet_fx15q` (Jomolhari): grass.png (source 0), snow_rock_tile.png (source 1), rock_tile.png (source 2), objects.png (source 3) — 4 sources

### 2.3 TileMap Data Format

The `tile_map_data` is a `PackedByteArray` encoding:
```
uint16 version    // always 0
uint16 count      // number of cells
then count × {
  int16 pos_x
  int16 pos_y
  uint16 tile_id
  uint16 source_id
}
```

The `y_sort_origin` in the `TileSetAtlasSource` defines the anchor point for Y-sorting (e.g., `y_sort_origin = 14` means the tile's bottom is at y=14, `y_sort_origin = 16` for props). For multi-cell tiles (trees, rocks, bushes), it must equal the distance from the tile's top edge down to where the artwork visually meets the ground - the tile then sorts as if it were a sprite standing on that line (verified by `tests/test_prop_sorting.gd`).

**Tile collision polygons** in `TileSetAtlasSource` physics layers are positioned by Godot relative to the **center of the tile's origin cell** (the top-left cell of the region) - NOT the center of the full multi-cell region. The props' trunk/footprint polygons were authored around the visible trunk relative to the region center, so each multi-cell tile's polygon is stored already shifted by the gap between those two reference points: `((width_cells - 1) * 8, (height_cells - 1) * 8)` for 16px tiles. Without that shift the collision floats up-left in the canopy: the student is stopped above the prop's base line and Y-sorting correctly draws the whole prop over them - the "hidden behind the tree while standing at its trunk" look. Never re-author these polygons from the TileSet editor's default reference without re-applying the shift (`test_tall_tile_collision_hugs_the_art_base` guards it).

**Y-sorted prop layers** (`yset`) must stay in the default z-index band (`z_index = 0`). Godot only Y-sorts items within the same band: a prop layer hoisted to `z_index = 1` draws over the player everywhere, whatever the per-tile sort origins say (`test_ysorted_prop_layers_stay_in_the_default_z_index_band` guards it).

### 2.4 Scene-to-Scene Transitions

**Exit areas** (`res://scripts/scene_exit.gd` — `extends Area2D`):

Node structure in map scenes:
```
ExitWest (Area2D)
├── CollisionShape2D (Rect_gate, size=Vector2(24, 192))
```
Properties: `target_scene` (String, .tscn path), `arrival_pos` (Vector2)

How it works:
1. `body_entered` signal triggers `_on_body_entered(body)`
2. Checks `body.is_in_group("player")`
3. Sets `Global.set_arrival_pos(arrival_pos)`
4. Calls `get_tree().change_scene_to_file.call_deferred(target_scene)` — deferred to avoid Godot collision overlap issues

**Exit nodes in Drakay Pangtsho:**
- `ExitWest` at position (16, 344) → `target_scene = "res://scenes/nyes/jhomo_lhari.tscn"`, `arrival_pos = Vector2(640, 344)`
- `ExitEast` at position (944, 344) → `target_scene = "res://scenes/nyes/tak_tsang.tscn"`, `arrival_pos = Vector2(48, 344)`

**Chorten shrine** (`res://scripts/narrative/chorten.gd` — `extends NPC`):
- Opens a `TravelMenu` when interacted with
- On destination chosen: hands the choice to the lobby's `LobbyTaxiStop` rank via `dispatch_outbound()`, which sends the taxi driving in; the student boards with E and rides to the realm (see TaxiRank below). The shrine releases itself right away, so it can be consulted again while the taxi waits; a second choice while a taxi is already inbound is refused with a message.
- When all realms are complete: offers "Rest" instead of travel, triggering `EndingSequence.start_dream()`

**Taxi rank** (`res://scripts/travel/taxi_rank.gd` — `class_name TaxiRank extends NPC`, scene `res://scenes/taxi_rank.tscn`):
- One shared script drives both journeys, in every location:
  - OUTBOUND: the shrine calls `dispatch_outbound(destination)`; the taxi tweens in along its approach lane and stops at the post. E boards (through the taxi's own `BoardArea`, not the post's talk circle — the taxi parks `lane_offset` from the post). Boarding hides the player, sets `Global.ui_locked`, reparents the player's `world_camera` onto the taxi, and tweens the taxi off past the stop before a `ScreenFade.fade_out` + scene change.
  - RETURN: standing at the post, the player presses T (`call_taxi` action, registered in the Input Map) to call the taxi in; E boards the same way.
  - ARRIVAL (both directions): before the scene change, `Global.begin_taxi_arrival(taxi_stop_path)` records the destination stop (a path relative to the destination scene's root). The rank it names claims the trip in `_ready` (resolving the path by node, not by string), then `_play_arrival()` runs: taxi drives in with the hidden player, stops at the post, pauses ~1.4 s, the player steps out exactly where the taxi stands (a zero-motion camera handoff) and the taxi drives off-screen, then control is restored and `arrival_completed` is emitted. `NyeMap._ready` and `Lobby._ready` clear any trip no rank claimed (missing stop) with a warning.
  - RETURN-HOME NARRATIVE: completing a realm queues a beat in `GameState` (`mark_realm_complete` increments it). When the taxi's arrival at the lobby's `LobbyTaxiStop` finishes, `Lobby._on_taxi_arrival_completed()` consumes the queue and plays the homecoming: fade to black with the wind/bell players, a glow around the student (artwork modulate tween), "The connection grows stronger..." across the curtain, fade to white, the shrine's glow visibly rising (`Chorten.play_return_brightening()`), then control back. It plays once per completed realm and never at quest completion time.
  - MUSIC DURING THE RIDE: no taxi code touches music at all. The `Music` autoload persists across the scene change, so the departure scene's track keeps playing through the drive, and the destination scene asks for its own track in `_ready()` — the crossfade lands under the arrival curtain. This is the persist-through-journey approach, chosen over fading to silence because it needs no extra code given the autoload (see §8.2).

**Global state for transitions** (`res://scripts/global.gd`):
- `set_arrival_pos(pos)` — stores position and sets `_has_arrival_pos = true`
- `take_arrival_pos()` — returns position, clears `_has_arrival_pos`
- `has_arrival_pos()` — returns whether a position is pending
- `current_scene: String` — tracks which scene is active ("game", "lobby", etc.)
- `transition_scene: bool` — flag indicating a scene change is in progress

**Scene loading and player placement:**
- `NyeMap._ready()` (shared by all nye maps): calls `Music.play_for_scene(scene_file_path, name)` (see §8), checks `Global.has_arrival_pos()`, sets `_player.global_position = Global.take_arrival_pos()`, calls `_apply_camera_limits()`, then `ScreenFade.fade_in()`
- `Lobby._ready()`: calls `Music.play_track(Music.LOBBY)`, calls `_apply_pending_spawn()` (same pattern), sets `Global.current_scene = "lobby"`
- `Game._ready()`: calls `Music.play_track(Music.TUTORIAL)`, calls `_apply_pending_spawn()`, sets `Global.current_scene = "game"`

---

## 3. Objects / Interactables

### 3.1 Node Structure for a Typical Interactable

Interactables come in three varieties:

**A) NPC-based interactables** (offering items, listening places, waste items):
These use the standard `npc.tscn` template — an instance of `res://scenes/npc.tscn`:
```
NPC (Area2D, group="npc") [collision_layer=0, collision_mask=1, y_sort_enabled=true]
├── Sprite2D (or AnimatedSprite2D for animated characters)
├── CollisionShape2D (CircleShape2D, radius=34.0)
└── Prompt (Label)
```

Properties set per-instance:
- `sequence` — the initial DialogueSequence (may be null)
- `sprite_texture` — the Texture2D for the Sprite2D
- `lore_key` — StringName used for GameState tracking (e.g., `&"drakay_waste_1"`, `&"drakay_view_north"`)
- `prompt_text` — shown above the character's head (default `"!"`)

**B) Area2D-based interactables** (Drakay water):
```
Water (Area2D)
├── CollisionShape2D (Rect_lake)
└── Prompt (Label, created programmatically in _ready())
```
Script: `res://scripts/narrative/drakay_water_interact.gd` — `extends Area2D`, `class_name DrakayWaterInteract`

**C) Node-based interactables** (ending water bowl):
```
EndingWaterBowl (Node2D, group="npc")
```
Script: `res://scripts/narrative/ending_water_bowl.gd` — `extends Node2D`

### 3.2 Interaction Detection

**NPC-based interaction flow:**
1. `NPC._ready()` connects `body_entered` and `body_exited` signals
2. On `body_entered`, if body is in group `"player"`, sets `_player_nearby = true` and shows `_prompt` if `has_talk()` is true
3. `has_talk()` returns: `_player_nearby and sequence != null and not DialogueManager.is_active`
4. Player presses interact key → `Player._unhandled_input()` calls `target.interact()`
5. `NPC.interact()` calls `DialogueManager.start(_pick_sequence())`

**DrakayWaterInteract interaction flow:**
1. `_ready()` adds self to group `"drakay_water"`, connects `body_entered`/`body_exited`
2. On `body_entered`, shows a programmatically-created `Prompt` Label with text "Examine water"
3. Player presses interact → `Player._unhandled_input()` calls `water.interact()`
4. `DrakayWaterInteract.interact()` calls `quest.on_water_noticed()` (quest is found via `get_node_or_null("../Quest")`)

**EndingWaterBowl interaction flow:**
1. `_physics_process` checks if player is within 60.0 distance
2. `has_talk()` checks: `not _interacted and GameState.has_seen(&"ending_dream_seen") and _player_nearby and not DialogueManager.is_active`
3. `interact()` calls `ending.finish_ending()` and starts `DialogueManager.start(ENDING_BOWL_SEQ)`

### 3.3 State Tracking

**Local scene state:** Each quest script (`DrakayPangtshoQuest`, `TaktsangQuest`, `JomolhariQuest`) maintains local variables like `_items: Array[NPC]`, `_places: Array[NPC]`, `_item_lines: Dictionary`, `_cues_noticed: bool`, `_memory_triggered: bool`.

**GameState autoload** (`res://scripts/game_state.gd`): The authoritative persistence layer:
- `seen_lore: Dictionary` — keys are StringNames like `&"drakay_waste_1"`, `&"drakay_quest_started"`, `&"ending_dream_seen"`
- `mark_seen(key)` — records a key in `seen_lore` and emits `lore_recorded` signal
- `first_time(key)` — returns true the first time a key is asked about, adds to `seen_lore`
- `has_seen(key)` — returns whether key exists in `seen_lore`
- Realm completion: `mark_realm_complete(realm)`, `is_realm_complete(realm)`
- Side quest completion: `mark_side_complete(realm)`, `is_side_complete(realm)`

**How collected state is set per object:**
- When an offering item is picked up, the quest script calls `GameState.mark_seen(_key_of(item))` in its `_on_dialogue_ended` handler
- The `_key_of(node)` helper returns `node.lore_key` if set, otherwise `StringName(String(node.get_path()))`
- After being marked seen, the quest's `_refresh()` sets `item.visible = false` and `item.sequence = null`, making the item disappear

---

## 4. Dialogue System

### 4.1 Node Structure of Dialogue UI

**`res://scenes/ui/dialogue_box.tscn`** — `DialogueBox` (`CanvasLayer`, layer=20):

```
DialogueBox (CanvasLayer)
├── Root (MarginContainer) [anchor_bottom=1, offset_top=-220, offset_bottom=-30]
│   └── Frame (PanelContainer)
│       └── Layout (VBoxContainer)
│           ├── Top (HBoxContainer)
│           │   ├── PortraitFrame (PanelContainer) [custom_minimum_size=Vector2(104,104)]
│           │   │   └── Portrait (TextureRect)
│           │   └── Col (VBoxContainer)
│           │       ├── Speaker (Label) [font_size=20, color=0.96,0.78,0.32]
│           │       └── Text (RichTextLabel) [font_size=18, bbcode_enabled=true]
│           └── Footer (HBoxContainer)
│               └── Indicator (Label) [text="▼", font_size=18]
```

**Script: `res://scenes/ui/dialogue_box.gd`** — `extends CanvasLayer`

### 4.2 Dialogue Data Format

**`DialogueLine`** (`res://scripts/dialogue/dialogue_line.gd` — `extends Resource`):
- `speaker: String` — who is talking
- `text: String` (multiline) — the spoken words, supports `{player}` placeholder
- `portrait: Texture2D` — optional portrait image

**`DialogueSequence`** (`res://scripts/dialogue/dialogue_sequence.gd` — `extends Resource`):
- `id: StringName` — stable identifier (e.g., `&"drakay_pangtsho_quest_intro"`)
- `lines: Array[DialogueLine]` — ordered conversation lines

Dialogue resources are stored as `.tres` files in `res://dialogue/`. Each is a `DialogueSequence` resource with a `lines` array of `DialogueLine` resources. Examples:
- `res://dialogue/drakay_pangtsho_quest_intro.tres`
- `res://dialogue/taktsang_monk_historical.tres`
- `res://dialogue/guide_intro.tres`

### 4.3 Dialogue Flow

**Triggering from an NPC:**
1. Player presses interact key near an NPC
2. `NPC.interact()` is called
3. `NPC._pick_sequence()` returns `sequence` (first visit) or `repeat_sequence` (subsequent visits), determined by `GameState.first_time(lore_key)`
4. `DialogueManager.start(_pick_sequence())` returns true if the conversation actually began

**DialogueManager** (`res://scripts/dialogue_manager.gd` — `extends Node`, autoload):
- `start(sequence)` — sets `_sequence = sequence`, `_index = 0`, emits `dialogue_started` and `line_changed`
- `advance()` — increments `_index`, emits `line_changed` for next line, or calls `_stop()` if past end
- `stop()` — ends conversation early
- `is_active` property — returns `_sequence != null`
- Signals: `dialogue_started(sequence)`, `line_changed(line, index)`, `dialogue_ended(sequence)`

**Line-by-line display** (`DialogueBox._process`):
- Characters are revealed at `CHARS_PER_SECOND = 45.0` per second
- While typing, `Text.text = _full_text.substr(0, int(_revealed))`
- After typing completes, shows the `▼` indicator
- Player presses interact (or `ui_accept`) to either finish typing or advance to the next line
- `{player}` in text is replaced with `GameState.player_name` before display

**DialogueBox listens to:**
- `DialogueManager.dialogue_started` → `_on_dialogue_started` → makes box visible, starts processing
- `DialogueManager.line_changed` → `_on_line_changed` → updates speaker text and portrait
- `DialogueManager.dialogue_ended` → `_on_dialogue_ended` → hides box, stops processing

### 4.4 Special Dialogue Behavior

**Jomolhari pacing/rush-detection (Drakay Pangtsho):**
In `DrakayPangtshoQuest._on_dialogue_ended`:
- `INTRO` sequence → sets `GameState.mark_seen(QUEST_STARTED)`, calls `_refresh()`
- `WATER_NOTICED` → `GameState.mark_seen(CUES_NOTICED)`, sets `_cues_noticed = true`, calls `_refresh()` (bonus awareness if noticed before being prompted)
- `WASTE_MEMORY` → marks the waste item as seen in GameState
- `OFFERING_MADE` → `_complete_offering()`: marks realm complete, adds awareness (3 base + 2 CUES_BONUS if noticed early), emits `offering_completed`, then calls `_balance_returns()` (plays bell, fades glow). The student is then free to walk back down the trek and call the taxi home; the return-home narrative plays in the lobby when that taxi arrives (see TaxiRank / Lobby below).

**Taktsang fragment-choice dialogue:**
In `TaktsangQuest._on_dialogue_ended`:
- `INTRO` → `GameState.mark_seen(QUEST_STARTED)`
- Fragment sequences (`HISTORICAL`, `PLAYFUL`, `PERSONAL`) → just `_refresh()`
- `RETELL_CHOICE` → `_handle_retelling_choice()`: uses `_last_choice_index` (tracked via `DialogueManager.line_changed` signal) to determine which fragment the player chose. `choice = clampi(_last_choice_index - 1, 0, 2)`. Marks `taktsang_chose_founding`, `taktsang_chose_tiger`, or `taktsang_chose_visitor` in GameState
- After retelling: `DialogueManager.start(BELL_RUNG_SEQ)`, then `DialogueManager.start(QUEST_COMPLETE_SEQ)`
- `_complete_quest()`: marks realm complete, adds 3 awareness, emits `quest_complete`, plays chant, fades glow

**Dialogue sequences for special behaviors:**
- The retell choice dialogue uses `_last_choice_index` which is updated on every `line_changed` signal — the index of the selected option determines the player's "choice" in the story

---

## 5. NPCs

### 5.1 Node Structure

**Base NPC template** (`res://scenes/npc.tscn` — `extends Area2D`, `class_name NPC`):

```
NPC (Area2D) [collision_layer=0, collision_mask=1, y_sort_enabled=true]
├── Sprite2D (position=(0,-24)) — for static characters
├── CollisionShape2D (CircleShape2D, radius=34.0)
└── Prompt (Label) [offset_top=-72, text="!", color=1,0.87,0.4]
```

**Animated NPC variant** (`res://scenes/monk.tscn`, `res://scenes/nyes/aum_jomo.tscn`, etc.):
```
NPC (Area2D) [collision_layer=0, collision_mask=1, y_sort_enabled=true]
├── AnimatedSprite2D (position=(0,-18)) — with sprite_frames and animation
├── CollisionShape2D (CircleShape2D, radius=34.0)
└── Prompt (Label)
```

### 5.2 NPC Script Logic

**`res://scripts/npc.gd`** — `class_name NPC extends Area2D`

**Exported variables:**
- `sequence: DialogueSequence` — the main conversation
- `prompt_text: String = "!"` — text shown in the prompt label
- `prompt_offset: Vector2 = Vector2(0, -60)` — offset for the prompt
- `sprite_texture: Texture2D` — for static Sprite2D characters
- `idle_animation: StringName = &"idle_front"` — animation for idle characters with AnimatedSprite2D
- `repeat_sequence: DialogueSequence` — conversation for subsequent visits
- `lore_key: StringName = &""` — key for GameState memory tracking

**Internal nodes** (`@onready`):
- `_sprite: Sprite2D = get_node_or_null("Sprite2D")`
- `_animated: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")`
- `_prompt: Label = $Prompt`

**Proximity detection:**
- `body_entered` → if body in group `"player"`, sets `_player_nearby = true`, shows prompt if `has_talk()`
- `body_exited` → sets `_player_nearby = false`, hides prompt

**Dialogue initiation:**
- `has_talk()` → `_player_nearby and sequence != null and not DialogueManager.is_active`
- `interact()` → calls `DialogueManager.start(_pick_sequence())`
- `_pick_sequence()` → uses `GameState.first_time(lore_key)` to choose between `sequence` (first) and `repeat_sequence` (subsequent)

**Animation:**
- `play_animation(animation)` → checks `_animated.sprite_frames.has_animation(animation)` and calls `_animated.play(animation)`
- In `_ready()`: `if _animated != null: play_animation(idle_animation)`

**Prompt bob:** `_process` adds `sin(_bob) * 3.0` to the prompt's Y position so it bounces gently.

### 5.3 Quest-State-Dependent NPC Behavior

Each realm's quest script controls NPC behavior by manipulating the `sequence` and `repeat_sequence` properties on NPC instances:

**DrakayPangtshoQuest** (`res://scripts/narrative/drakay_pangtsho_quest.gd`):
- In `_refresh()`: sets `_tshomen.sequence = QUEST_DONE` when realm complete, `_altar.sequence = ALTAR_WAITING/OFFERING/HONOURED` depending on offering progress, `_items[i].sequence = null` when carried, `_places[i].sequence = _place_lines[place]` when started
- `_items` are NPC instances in group `"offering_item"`, `_places` are in group `"listening_place"`

**TaktsangQuest** (`res://scripts/narrative/taktsang_quest.gd`):
- `_refresh()`: sets `_historical_monk.sequence = HISTORICAL_SEQ` (or null if already seen), `_monk.sequence` changes from `INTRO_SEQ` → null (all fragments collected) → `QUEST_COMPLETE_SEQ` (realm done)
- `_monk.repeat_sequence` changes from `RETELL_CHOICE_SEQ` to `QUEST_REPEAT_SEQ` when finished

**JomolhariQuest** (`res://scripts/narrative/jomolhari_quest.gd`):
- `_refresh()`: sets `_jomo.sequence = JOMO_DONE`, `_jomo.repeat_sequence = JOMO_LORE` when finished
- Item NPCs become invisible when their `lore_key` is in `seen_lore`

**HerderQuest** (`res://scripts/narrative/herder_quest.gd` — "The Herder's Path", Jomolhari's second side quest):
- Owns Dema (`Dema`), four clue-marker NPCs in group `"herder_clue"` (`ClueBranch`, `ClueWool`, `ClueTracks`, `ClueWoolBush`, wired in trail order via the exported `clue_paths` array) and the `Yak` NPC — all in `res://scenes/nyes/jhomo_lhari.tscn`
- Clue markers only become interactable one at a time, in walking order: clue *i* gets its `sequence` once `herder_quest_started` is seen and clues *0..i-1* have each been read (each clue records itself via its `lore_key`). Skipping ahead does nothing — the player must backtrack to the unread sign
- The yak stays inert until all four clues are read; found, it hides (it follows the student down), and Dema's `sequence` switches to `HERDER_THANKS`
- `_complete_quest()` (on the thanks ending) sets `GameState.jomolhari_side2_complete = true`, `GameState.has_woven_cord = true`, calls `GameState.add_awareness(1)`, and the yak reappears standing beside Dema (`home_offset`)

**MendingQuest** (`res://scripts/narrative/mending_quest.gd` — "Mending What's Shared", Drakay Pangtsho's second side quest):
- Owns Choden (`Choden`), three reed-stand NPCs in group `"mending_reed"` (`ReedWest`, `ReedNorth`, `ReedEast` — collected from the group but filtered to this map's own children) and the torn `Platform` marker — all in `res://scenes/nyes/drakay_pangtsho.tscn`
- Reed stands become interactable once `mending_quest_started` is seen; cutting one (its conversation read through) marks its `lore_key` and hides it. The platform only offers the repair once all three bundles are carried
- The repair (`mending_repair`) is a hands-on mini-task done beside Choden, using the same pacing gate as the Jomolhari offering: each advance must be ≥ `REPAIR_MIN_INTERVAL_MS` (900ms) apart or the cord "slips" (`DialogueManager.stop()` → `mending_rushed` interrupt line → the platform offers the repair again). Choden speaks throughout the repair sequence
- `_complete_repair()` (on a deliberate, unhurried ending) sets `GameState.drakay_pangtsho_side2_complete = true`, calls `GameState.add_awareness(1)`, then auto-starts `mending_lore` — Choden's grandmother's ledger-of-the-lake story, found nowhere else in the game. Choden's standing talk afterwards is the short `mending_done` line

**PilgrimQuest** (`res://scripts/narrative/pilgrim_quest.gd` — "The Pilgrim's Climb", Taktsang's second side quest):
- Owns Dolma (`Pilgrim`, an instanced `res://scenes/pilgrim.tscn` — an animated NPC with `idle_front`/`walk_side` animations from `res://assets/generated/pilgrim_dolma_frames.tres`) — placed partway up the trail at `(1120, 384)` in `res://scenes/nyes/tak_tsang.tscn`, with the `PilgrimQuest` node exporting `pilgrim_path` and `viewpoint` (`Vector2(1744, 152)`, the courtyard viewpoint by the monastery gate)
- Talking to her (E, the usual Area2D prompt) plays `pilgrim_intro`; hearing it through marks `pilgrim_quest_started` and begins the escort. Her standing talk during the escort is the short `pilgrim_reminder`
- The escort is a distance-based pace gate (deliberately distinct from Jomolhari's input-timing gate and the mending's between-press gate): in `_physics_process` she follows the student at a fixed `FOLLOW_SPEED` (40 px/s vs the student's 100), stopping `FOLLOW_GAP` (28px) short of them. If the student pulls more than `PAUSE_DISTANCE` (120px) ahead she plants her stick, calls out (`pilgrim_callout`, re-fired at most every `CALLOUT_COOLDOWN_S` = 6s) and waits; she only resumes once the student comes back within `RESUME_DISTANCE` (72px)
- Within `LAST_STRETCH` (64px) of the viewpoint she stops following and walks the last steps herself, so a gap can never strand her short of the top; within `ARRIVE_RADIUS` (28px) the escort ends
- `_complete()` sets `GameState.taktsang_side2_complete = true`, calls `GameState.add_awareness(1)`, snaps her to the viewpoint and — after `ARRIVED_DELAY_S` (1.0s) — auto-starts `pilgrim_arrived`, whose final line is her ending dialogue: "Worth arguing for." Her standing talk afterwards is the short `pilgrim_done`; on any later visit she stands at the viewpoint looking out

**Inconsistency note:** The `DrakayPangtshoQuest` has `tshomen_path`, `altar_path`, etc. as `@export var` paths resolved via `_find()`, while `TaktsangQuest` and `JomolhariQuest` use the same `_find()` pattern. All three use `DialogueManager.dialogue_ended.connect(_on_dialogue_ended)` in `_ready()`. The `DrakayPangtshoQuest` additionally connects `_clean_water_layer` via `get_node_or_null("../CleanWater")` and tracks `_cues_noticed` and `_memory_triggered` state that the other two quests don't have.

### 5.4 Chorten (Shrine)

**`res://scripts/narrative/chorten.gd`** — `class_name Chorten extends NPC`

The Chorten extends NPC but overrides `interact()` to open a travel menu instead of starting dialogue. Properties:
- `destinations: Array[TravelDestination]` — the realms to travel to
- `guide_path: NodePath` — optional guide NPC whose `finished_talking` signal opens the menu
- `_symbols: HBoxContainer` — contains `TextureRect` marks for each realm
- `_glow: Sprite2D` — visual glow above the dome

`_refresh()` colors each symbol: `lit_tint` if realm complete, `dim_tint` otherwise. `_glow.modulate.a` increases with each completed realm. When all realms are complete, `has_talk()` returns true and `interact()` calls `_endings_rest()` which triggers `EndingSequence.start_dream()`.

---

## 6. Movement

### 6.1 Exact Script and Node

**Script:** `res://scripts/player.gd` — `extends CharacterBody2D`

**Node:** `Player` in `res://scenes/player.tscn` — `CharacterBody2D` type, in group `"player"`

### 6.2 Input Actions

**Primary movement actions:**
- `"ui_left"`, `"ui_right"`, `"ui_up"`, `"ui_down"` — Godot built-in actions (WASD + arrow keys)
- `"move_left"`, `"move_right"`, `"move_up"`, `"move_down"` — fallback custom actions

**Interaction action:**
- `"interact"` — used by `Player._unhandled_input()` to trigger talk/examine
- `"ui_accept"` — used by `DialogueBox._unhandled_input()` to advance dialogue
- `"ui_cancel"` — used by `TravelMenu._unhandled_input()` to dismiss the menu

All these must be defined in the project's Input Map (Project Settings → Input Map).

### 6.3 Movement States

**Normal movement** (`_physics_process`):
- `direction = Input.get_vector(...)` produces a Vector2
- If non-zero: `velocity = direction * SPEED` (100.0), `_animate(true)`
- If zero: `velocity = Vector2.ZERO`, `_animate(false)`
- `move_and_slide()` always called

**Dialogue-locked** (`DialogueManager.is_active or Global.ui_locked`):
- `velocity = Vector2.ZERO`, `_animate(false)`
- `move_and_slide()` still called to maintain physics state
- Returns early from `_physics_process`

**Village tutorial movement** (`VillageQuests._process`):
- Uses `get_tree().get_first_node_in_group("player")` to find the player
- Tracks `_last_pos` and checks `distance_to(_last_pos) >= MOVE_THRESHOLD` (12.0)
- When threshold reached, calls `_advance()` which increments the tutorial step and adds awareness

---

## 7. GameState / Progression Tracking

### 7.1 Every Variable in GameState Autoload

**File:** `res://scripts/game_state.gd` — `extends Node`, autoload singleton

**Signals:**
| Signal | Parameters | When emitted |
|---|---|---|
| `awareness_changed` | `value: int` | Whenever `awareness` setter fires |
| `realm_completed` | `realm: StringName` | First time a realm is marked complete |
| `side_quest_completed` | `realm: StringName` | First time a side quest is marked complete |
| `lore_recorded` | `key: StringName` | When a key is first added to `seen_lore` |

**Variables:**
| Variable | Type | Default | Description |
|---|---|---|---|
| `player_name` | `String` | `"Tashi"` | The student's name |
| `awareness` | `int` | `0` | Understanding level. Clamped to ≥0 via setter. Emits `awareness_changed` on change. |
| `jomolhari_complete` | `bool` | `false` | Realm completion flag |
| `drakay_pangtsho_complete` | `bool` | `false` | Realm completion flag |
| `taktsang_complete` | `bool` | `false` | Realm completion flag |
| `jomolhari_side_complete` | `bool` | `false` | Side quest completion flag |
| `drakay_pangtsho_side_complete` | `bool` | `false` | Side quest completion flag |
| `taktsang_side_complete` | `bool` | `false` | Side quest completion flag |
| `jomolhari_side2_complete` | `bool` | `false` | "The Herder's Path" completion flag (Jomolhari's second side quest, set directly by `HerderQuest._complete_quest()`) |
| `drakay_pangtsho_side2_complete` | `bool` | `false` | "Mending What's Shared" completion flag (Drakay Pangtsho's second side quest, set directly by `MendingQuest._complete_repair()`) |
| `taktsang_side2_complete` | `bool` | `false` | "The Pilgrim's Climb" completion flag (Taktsang's second side quest, set directly by `PilgrimQuest._complete()`) |
| `has_woven_cord` | `bool` | `false` | Dema's woven cord, given when the lost yak comes home. A keepsake, only referenced in dialogue. |
| `seen_lore` | `Dictionary` | `{}` | Keys are `StringName`, values are `true` |

**Constant:**
- `DEFAULT_PLAYER_NAME: String = "Tashi"`
- `REALMS: Array[StringName] = [&"drakay_pangtsho", &"taktsang", &"jomolhari"]`

### 7.2 Every Function in GameState

| Function | Parameters | Returns | Description |
|---|---|---|---|
| `add_awareness` | `amount: int = 1` | `void` | `awareness += amount` (goes through setter) |
| `reset_awareness` | — | `void` | Sets `awareness = 0` (bypasses setter's clamp check) |
| `first_time` | `key: StringName` | `bool` | Returns true if key not in `seen_lore`, adds it. Returns false on subsequent calls. |
| `mark_seen` | `key: StringName` | `void` | Adds key to `seen_lore` if not present, emits `lore_recorded` |
| `has_seen` | `key: StringName` | `bool` | `seen_lore.has(key)` |
| `mark_realm_complete` | `realm: StringName` | `void` | Validates against `REALMS`, sets flag, emits `realm_completed` |
| `is_realm_complete` | `realm: StringName` | `bool` | Match on realm name returns flag, warns on unknown |
| `completed_realm_count` | — | `int` | Counts realms where `is_realm_complete` returns true |
| `retreat_finished` | — | `bool` | `completed_realm_count() == REALMS.size()` |
| `mark_side_complete` | `realm: StringName` | `void` | Validates, sets side flag, emits `side_quest_completed` |
| `is_side_complete` | `realm: StringName` | `bool` | Match on realm returns side flag |
| `reset` | — | `void` | Resets all variables to defaults, clears `seen_lore` |
| `_set_realm_flag` | `realm, value` | `void` | Internal match-based flag setter |
| `_set_side_flag` | `realm, value` | `void` | Internal match-based flag setter |

**Who sets what:**
- `mark_realm_complete` is called by quest scripts (`DrakayPangtshoQuest._complete_offering()`, `TaktsangQuest._complete_quest()`, `JomolhariQuest._complete_offering()`)
- `mark_side_complete` is called by quest scripts (`JomolhariQuest._check_listening()`, `TaktsangQuest._check_listening()`)
- `mark_seen` is called by quest scripts when items are collected or conversations happen
- `add_awareness` is called by quest scripts on completion (3-5 points per realm)

### 7.3 How Quest Completion Flows into GameState

**Drakay Pangtsho:**
1. `DrakayPangtshoQuest._complete_offering()` → `GameState.mark_realm_complete(REALM)` → `mark_side_complete(REALM)` is NOT called here (side quest is separate — listening places)
2. `DrakayPangtshoQuest._check_listening()` → `GameState.mark_side_complete(REALM)` when all 3 listening places sat at
3. `GameState.add_awareness(OFFERING_AWARENESS)` (3) + `CUES_BONUS` (2) if noticed early
4. Then `_balance_returns()` (plays bell, tweens glow). The quest then leaves the student in the realm; the return-home narrative plays later, in the lobby, when the taxi brings them back (see §2.4).
5. Second side quest, "Mending What's Shared" (`MendingQuest`, fully separate from the above): Choden's intro → 3 reed stands cut → paced repair at the platform (hurrying slips the cord and restarts) → completion sets `drakay_pangtsho_side2_complete`, adds `SIDE_AWARENESS` (1), and auto-plays Choden's unique lake-ledger lore. It does not touch the realm, the reflections quest's flags, or the offering.

**Taktsang:**
1. `TaktsangQuest._complete_quest()` → `GameState.mark_realm_complete(REALM)` → `GameState.add_awareness(COMPLETE_AWARENESS)` (3)
2. Then `_peace_returns()` (plays chant, tweens glow); the return-home narrative plays on the later taxi arrival in the lobby
3. Second side quest, "The Pilgrim's Climb" (`PilgrimQuest`, fully separate from the above): Dolma's intro → escort up the remaining trail at her pace (pull >120px ahead and she stops, calls out and waits until you come back within 72px) → her arrival at the viewpoint sets `taktsang_side2_complete` and adds `SIDE_AWARENESS` (1), then auto-plays her "Worth arguing for." ending. It does not touch the realm, the prayer-wheels quest's `taktsang_side_complete`, or the three keepers.

**Jomolhari:**
1. `JomolhariQuest._complete_offering()` → `GameState.mark_realm_complete(REALM)` → `GameState.add_awareness(OFFERING_AWARENESS)` (3)
2. `JomolhariQuest._check_listening()` → `GameState.mark_side_complete(REALM)` when all 3 places sat at, adds `LISTENING_AWARENESS` (1)
3. Then `_balance_returns()`; the return-home narrative plays on the later taxi arrival in the lobby
4. Second side quest, "The Herder's Path" (`HerderQuest`, fully separate from the above): intro → 4 clue markers read in order → yak found → Dema's thanks sets `jomolhari_side2_complete` + `has_woven_cord` and adds `SIDE_AWARENESS` (1). It does not touch the realm or listening-quest flags.

### 7.4 How the Lobby/Shrine Reflects GameState Visually

**Chorten** (`res://scripts/narrative/chorten.gd`):
- `GameState.realm_completed.connect(_on_realm_completed)` → calls `_refresh()`
- `_refresh()` colors each `TextureRect` mark in `_symbols`: `lit_tint` if realm complete, `dim_tint` otherwise
- `_glow.modulate.a` increases from `base_glow` (0.16) by `glow_per_realm` (0.22) per completed realm
- When `GameState.retreat_finished()`: prompt text changes from `"!"` to `"Rest"`, `_glow.modulate.a = 1.0`
- `open_menu()` shows the `TravelMenu` if destinations available, or calls `_endings_rest()` if retreat is finished

**Mood changes** in quest scenes:
- `CanvasModulate` nodes (`Mood`) are colored by quest scripts: `waiting_light` before completion, `offering_light` after
- `DrakayPangtshoQuest`: `Color(0.5, 0.6, 0.85)` → `Color(0.87, 0.9, 0.97)`
- `TaktsangQuest`: `Color(0.5, 0.6, 0.85)` → `Color(1.06, 0.99, 0.90)`
- `JomolhariQuest`: `Color(0.87, 0.90, 0.97)` → `Color(1.06, 0.99, 0.90)`

**VillageOpening** (`res://scripts/narrative/village_opening.gd`):
- `CanvasModulate` color is `OFF_MOOD = Color(0.66, 0.71, 0.82)` on first visit, `NORMAL_MOOD = Color(1, 1, 1)` on subsequent visits
- `GameState.first_time(&"opening_seen")` controls whether the dream plays

---

## 8. Audio / Background Music

### 8.1 The Music Autoload

**`res://scripts/music.gd`** — `extends Node`, registered as the `Music` autoload in `project.godot` (after `GameState`). All background-track playback lives here so scene code never owns an `AudioStreamPlayer` or fade logic of its own. The autoload persists across scene changes — that is what lets a taxi ride keep the departure scene's music playing through the journey.

**Track constants** (all preloaded, all files in `res://assets/audio/music/`):

| Constant | File | Used by |
|---|---|---|
| `Music.TUTORIAL` | `tutorial.ogg` | Village / tutorial scene (`game.tscn`) |
| `Music.DREAM` | `dream.mp3` | Opening dream **and** ending dream — one track shared by both, per the story's intent that the two moments keep one sonic identity |
| `Music.LOBBY` | `lobby.wav` | Crossroads / lobby scene (`lobby.tscn`), including taxi returns |
| `Music.JOMOLHARI` | `jomolhari.wav` | `nyes/jhomo_lhari.tscn` |
| `Music.DRAKAY_PANGTSHO` | `drakeypangtsho.wav` | `nyes/drakay_pangtsho.tscn` |
| `Music.TAKTSANG` | `taktsang.wav` | `nyes/tak_tsang.tscn` |

**API:**

| Function | Description |
|---|---|
| `play_track(stream: AudioStream, fade_duration: float = 1.0)` | Crossfades from whatever is playing to `stream`: the old player fades out while the new one fades in (SINE-eased `volume_db` tweens between `SILENT_DB` −60 and `FULL_DB` 0). **No-ops if the requested stream is already the current one** — re-entering a scene never restarts the music. A `null` stream fades to silence. |
| `stop_track(fade_duration := 1.0)` | Fades the current track down to silence. |
| `play_for_scene(scene_path: String, root_name: String = "")` | Plays the track mapped to a scene file (`TRACK_BY_SCENE_FILE`) or root node name (`TRACK_BY_ROOT_NAME`, covers instanced maps). **Unmapped scenes — the shrine interiors and the dzong — keep the current track**, so interiors share their realm's music instead of going quiet or restarting. |
| `current_track() -> AudioStream` | The track playing (or fading in), or `null` in silence. |
| `active_player() -> AudioStreamPlayer` | The player the current track is loaded into (mainly for tests). |
| `silence_now()` | Stops and frees every player at once, discarding in-flight fades (test teardown runs between frames the fades would have needed). |

Internals: one `_active` player for the current track; retired players live in `_dying` and free themselves when their fade-out tween lands (each player has at most one live fade — `Music` kills any prior tween before starting a new one, so two tweens can never fight over one `volume_db`). The same-track guard keys off `_current`, not `.playing`, because headless runs never start audible playback (see §8.4).

### 8.2 Where each scene wires in

| Scene / moment | Script and call | Track |
|---|---|---|
| Village / tutorial load | `game.gd` `_ready()` → `Music.play_track(Music.TUTORIAL)` | tutorial.ogg |
| Opening dream begins | `village_opening.gd` `_start_dream()` → `Music.play_track(Music.DREAM)` | dream.mp3 |
| Ending dream begins | `ending_sequence.gd` `_start_dream()` → `Music.play_track(Music.DREAM)` | dream.mp3 |
| Wake from either dream | `village_opening.gd` `_after_dream()` → `Music.play_track(Music.TUTORIAL)` — runs for both dreams because they play through the same `DreamOverlay`; `ending_sequence.gd`'s `_after_dream()` fallback path (missing overlay) resumes it too | tutorial.ogg |
| Lobby load | `lobby.gd` `_ready()` → `Music.play_track(Music.LOBBY)` | lobby.wav |
| Nye map load | `nye_map.gd` `_ready()` → `Music.play_for_scene(scene_file_path, name)` | per-map |

**Taxi journeys (both directions): persist-through-journey.** The departure scene's track simply keeps playing through the drive because the autoload survives the scene change; the destination scene requests its own track in `_ready()` and the crossfade happens there, under the arrival curtain. Zero taxi code is involved — this was chosen over fade-to-silence precisely because it is the approach that needs no extra code.

**Pausing:** nothing in the game pauses the scene tree, and **dialogue alone never pauses the music** — the current scene's track keeps playing under conversations, per the ambient design. The Music node is `PROCESS_MODE_ALWAYS`, so it would also survive any future full pause.

### 8.3 Looping (measured from the source files)

Every provided track was authored with a fade-out at the end followed by a pad of silence; looping the raw file would breathe a silent dip into the ambience on every repeat. There are **no clicks at any seam** — the end and start samples match to ~zero. The measured pads:

| File | Trailing silence pad | Lead-in |
|---|---|---|
| `drakeypangtsho.wav` | ~7.2 s | ~3 ms |
| `jomolhari.wav` | ~1.8 s | ~1 ms |
| `lobby.wav` | ~2.1 s | ~1 ms |
| `taktsang.wav` | ~3.2 s | ~152 ms |
| `dream.mp3` | ~4.2 s | ~0.6 s |
| `tutorial.ogg` | ~0.24 s (short fade-down) | ~1 ms |

Looping is enabled at **playback time** in `_ensure_loop()` — the `.import` files and the audio files themselves are untouched:

- **WAVs** get `loop_mode = LOOP_FORWARD` plus measured loop points from `LOOP_POINTS_BY_FILE` (`Vector2i(loop_begin, loop_end)`, samples at 44.1 kHz, clamped to the imported frame count). This trims the authored fade-out and silence pad out of the loop, so all four WAVs loop seamlessly, carrying sound right up to the seam. `taktsang.wav`'s 152 ms lead-in is also skipped via `loop_begin`.
- **Ogg Vorbis and MP3 only support a loop *begin* offset (`loop_offset`), not a loop end**, so their trailing pad cannot be trimmed at playback time. `dream.mp3`'s 0.6 s lead-in is skipped via `loop_offset = 0.595`, but its ~4.2 s authored fade-out + silence still plays once per repeat — **the one known non-seamless loop point**. Fixing it requires re-encoding the file with the tail trimmed; the file was deliberately not modified. `tutorial.ogg`'s 0.24 s pad is mild and carries the same limitation.

### 8.4 Headless behavior (why tests don't start playback)

Godot's headless audio driver pins any stream ever `play()`ed for the rest of the process — the playback queue is never drained, and even `stop()` + `stream = null` + freeing the player does not release it. That surfaced as `ERROR: N resources still in use at exit` in the headless test harness (it flips the suite's verdict). `Music` therefore skips starting audible playback when `DisplayServer.get_name() == "headless"`; `_retire()` likewise releases retired players immediately instead of fading them. The real game always runs with a real audio driver, and all track-state logic (crossfades, same-track guard, mappings) is identical either way — the tests assert on the hand-off structure rather than audible playback.

### 8.5 Tests

`res://tests/test_music.gd` (9 tests) covers: the same-track guard (re-asking spawns nothing), crossfade structure (old player retained to fade out, new player set up to fade in from `SILENT_DB`), switching back to a track still fading out, fading to silence on a null track, the scene-file mapping for all three nye maps, the root-name mapping for instanced maps, unmapped scenes (shrine interiors) keeping the current track, loop flags/points applied to every provided file, and loop points staying inside their streams. `after_each()` calls `Music.silence_now()` so no stream is left referenced between tests.

---

## Inconsistencies and Notes

1. **`frame_progress` on Player vs NPCs:** The `player.tscn` `AnimatedSprite2D` has `frame_progress = 0.54092306`, while `aum_jomo.tscn`, `tshomen.tscn`, and `guide.tscn` had this value removed (it was causing Z-order glitches in NPCs).

2. **NPC sprite types:** Some NPCs use `Sprite2D` with `sprite_texture` (e.g., the Altar in Drakay Pangtsho uses `sprite_texture = ExtResource("8_stupa.png")`), while others use `AnimatedSprite2D` with `sprite_frames`. The `npc.gd` script handles both via `_sprite` and `_animated` `@onready` lookups.

3. **Quest script patterns differ slightly:** `DrakayPangtshoQuest` has `_cues_noticed`, `_memory_triggered`, and `_clean_water_layer` state that `TaktsangQuest` and `JomolhariQuest` don't. `TaktsangQuest` has the fragment-choice mechanic with `_last_choice_index` tracked via `line_changed`. `JomolhariQuest` is the simplest, with no special quest state beyond offering/listening tracking.

4. **`DrakayPangtsho` has both `ground` and `props` with the same `tile_map_data`** — this is because the `props` `tile_map_data` was used as a template when restoring the `ground` node. The ground uses `TileSet_lh53h` and props uses `TileSet_props` — different tilesets, same cell layout.

5. **The `CleanWater` TileMapLayer** exists only in Drakay Pangtsho and is controlled by the quest script's visibility toggle. Other maps don't have a comparable water overlay layer.

6. **`Global.finish_changescenes()`** is a legacy method that swaps `current_scene` between `"game"` and `"lobby"`. It's called by `Game.change_scene()` and `Lobby._process()` but the actual scene transition is done via `get_tree().change_scene_to_file.call_deferred()`.

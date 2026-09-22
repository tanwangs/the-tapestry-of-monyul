# The Tapestry of Monyul — Project Documentation

## 1. Project Overview

**Title:** The Tapestry of Monyul

**Premise:** A young villager named Tashi rediscovers attentiveness and balance by visiting three sacred sites across the Himalayan landscape of Bhutan. The retreat is structured as a journey from the village crossroads through three realms — Drakay Pangtsho, Taktsang, and Jomolhari — each with its own quest, characters, and landscape. The story culminates in a dream sequence and a final choice at the household shrine.

**Core Theme:** The narrative explores attentiveness — learning to notice visual cues, listen to stories, and tend to the world around you. Each realm teaches a different aspect of this: noticing at Drakay Pangtsho, storytelling at Taktsang, and offering at Jomolhari.

**Player Character:** Tashi (default name, configurable), a student on a nature retreat who walks the landscape, talks to characters, and completes quests.

---

## 2. Scene Structure

### 2.1 Main Scenes

| Scene File | Represents | Transitions To | Trigger |
|---|---|---|---|
| `res://scenes/game.tscn` | Main world map (village/landscape) | — | Initial scene |
| `res://scenes/lobby.tscn` | Village crossroads and shrine | `game.tscn`, `nyes/drakay_pangtsho.tscn`, `nyes/tak_tsang.tscn`, `nyes/jhomo_lhari.tscn` | Chorten shrine interaction |
| `res://scenes/nyes/drakay_pangtsho.tscn` | Drakay Pangtsho realm (lake, altar, viewpoints) | `lobby.tscn` | ExitWest/ExitEast areas |
| `res://scenes/nyes/tak_tsang.tscn` | Taktsang realm (monastery, dzong) | `lobby.tscn` | Exit areas |
| `res://scenes/nyes/jhomo_lhari.tscn` | Jomolhari realm (altar, shrine) | `lobby.tscn` | Exit areas |
| `res://scenes/nyes/drakay_pangtsho_shrine.tscn` | Drakay Pangtsho shrine interior | — | Entrance area |
| `res://scenes/nyes/tak_tsang_dzong.tscn` | Taktsang dzong interior | — | Entrance area |
| `res://scenes/nyes/jhomo_lhari_shrine.tscn` | Jomolhari shrine interior | — | Entrance area |
| `res://scenes/monk.tscn` | Monk NPC (Taktsang keepers) | — | Instance in tak_tsang.tscn |
| `res://scenes/npc.tscn` | Base NPC template (Area2D + AnimatedSprite2D + CollisionShape2D + Prompt) | — | Base template for other NPCs |
| `res://scenes/player.tscn` | Player character (CharacterBody2D + AnimatedSprite2D) | — | Instance in game/nye maps |
| `res://scenes/nyes/aum_jomo.tscn` | Aum Jomo NPC | — | Instance in jhomo_lhari.tscn |
| `res://scenes/nyes/tshomen.tscn` | Tshomen NPC | — | Instance in drakay_pangtsho.tscn |
| `res://scenes/nyes/guide.tscn` | Guide NPC | — | Instance in lobby.tscn |
| `res://scenes/chorten.tscn` | Shrine at crossroads | — | Instance in lobby.tscn |
| `res://scenes/taxi_rank.tscn` | Taxi rank | `game.tscn`, `lobby.tscn` | Scene transition |
| `res://scenes/travel_guide.tscn` | Travel guide NPC | — | — |
| `res://scenes/_objects_viewer.tscn` | Object viewer (debug) | — | — |
| `res://scenes/_plains_viewer.tscn` | Plains viewer (debug) | — | — |

### 2.2 UI Scenes

| Scene File | Represents |
|---|---|
| `res://scenes/ui/dialogue_box.tscn` | Dialogue display box |
| `res://scenes/ui/dream_overlay.tscn` | Dream sequence overlay |
| `res://scenes/ui/quest_hud.tscn` | Quest progress HUD |
| `res://scenes/ui/travel_menu.tscn` | Travel destination menu |

### 2.3 Transition Flow

```
game.tscn → lobby.tscn (via scene_exit) → nye maps (via chorten)
nye maps → lobby.tscn (via exit areas)
lobby.tscn → game.tscn (via ending_sequence)
```

Scene transitions use `Global.set_arrival_pos()` and `Global.transition_scene` / `Global.current_scene` flags, with `ScreenFade.fade_in()` / `ScreenFade.fade_out()` for visual transitions.

---

## 3. Core Systems

### 3.1 GameState Autoload (`res://scripts/game_state.gd`)

**Type:** `extends Node` — Autoload singleton

**Variables:**

| Variable | Type | Default | Description |
|---|---|---|---|
| `player_name` | `String` | `"Tashi"` | The student's name |
| `awareness` | `int` | `0` | How much the student has come to understand. Grows as the retreat progresses. |
| `jomolhari_complete` | `bool` | `false` | Whether the Jomolhari realm is finished |
| `drakay_pangtsho_complete` | `bool` | `false` | Whether the Drakay Pangtsho realm is finished |
| `taktsang_complete` | `bool` | `false` | Whether the Taktsang realm is finished |
| `jomolhari_side_complete` | `bool` | `false` | Whether the Jomolhari side quest is complete |
| `drakay_pangtsho_side_complete` | `bool` | `false` | Whether the Drakay Pangtsho side quest is complete |
| `taktsang_side_complete` | `bool` | `false` | Whether the Taktsang side quest is complete |
| `seen_lore` | `Dictionary` | `{}` | Tracks which lore/conversations have been seen, keyed by StringName |

**Signals:**

| Signal | Parameters | Description |
|---|---|---|
| `awareness_changed` | `value: int` | Emitted whenever `awareness` changes |
| `realm_completed` | `realm: StringName` | Emitted the first time a realm is marked finished |
| `side_quest_completed` | `realm: StringName` | Emitted the first time a side quest is marked finished |
| `lore_recorded` | `key: StringName` | Emitted when a piece of lore is first recorded |

**Functions:**

| Function | Parameters | Returns | Description |
|---|---|---|---|
| `add_awareness` | `amount: int = 1` | `void` | Increases awareness by the given amount |
| `reset_awareness` | — | `void` | Resets awareness to 0 |
| `first_time` | `key: StringName` | `bool` | Returns true the first time this key is asked about, false every time after. Adds the key to `seen_lore`. |
| `mark_seen` | `key: StringName` | `void` | Records a key as seen in `seen_lore` |
| `has_seen` | `key: StringName` | `bool` | Returns whether a key has been seen |
| `mark_realm_complete` | `realm: StringName` | `void` | Marks a realm as complete (validates against `REALMS` list) |
| `is_realm_complete` | `realm: StringName` | `bool` | Returns whether a realm is complete |
| `mark_side_complete` | `realm: StringName` | `void` | Marks a side quest as complete |
| `is_side_complete` | `realm: StringName` | `bool` | Returns whether a side quest is complete |
| `retreat_finished` | — | `bool` | Returns whether all three realms are complete |

**Constants:**

| Constant | Value | Description |
|---|---|---|
| `DEFAULT_PLAYER_NAME` | `"Tashi"` | Default player name |
| `REALMS` | `[&"drakay_pangtsho", &"taktsang", &"jomolhari"]` | The three realms in trek order |

---

### 3.2 Dialogue System

**How it's triggered:** The player walks near an NPC and presses the interact key (E, Space, or Enter). `Player._unhandled_input()` calls `NPC.interact()`, which calls `DialogueManager.start(sequence)`.

**Data format:** Dialogue sequences are `DialogueSequence` resources (`res://dialogue/*.tres`). Each sequence contains an array of `DialogueLine` resources.

**Key nodes/scripts:**

| Node/Script | File | Description |
|---|---|---|
| `DialogueManager` | `res://scripts/dialogue_manager.gd` | Autoload singleton. Plays `DialogueSequence` resources. Signals: `dialogue_started`, `line_changed`, `dialogue_ended`. Property: `is_active` (bool). |
| `NPC` | `res://scripts/npc.gd` | Base NPC class. Has `sequence` (DialogueSequence), `repeat_sequence`, `lore_key`, `prompt_text`, `sprite_texture`, `idle_animation`. Uses `body_entered`/`body_exited` signals for proximity detection. `has_talk()` checks if player is nearby and sequence exists. |
| `DialogueLine` | `res://scripts/dialogue/dialogue_line.gd` | Single line of dialogue text |
| `DialogueSequence` | `res://scripts/dialogue/dialogue_sequence.gd` | Collection of dialogue lines |
| `DialogueBox` | `res://scenes/ui/dialogue_box.tscn` | UI scene instanced in map scenes (e.g., `drakay_pangtsho.tscn` via `instance=ExtResource("90_dialogue")`) |

**Dialogue flow:**
1. Player presses interact key near NPC
2. `NPC.interact()` checks `has_talk()` — player nearby, sequence not null, DialogueManager not active
3. `NPC._pick_sequence()` returns `sequence` on first visit, `repeat_sequence` on subsequent visits (checked via `GameState.first_time(lore_key)`)
4. `DialogueManager.start(sequence)` begins playback
5. Each line advancement calls `DialogueManager.advance()`
6. After last line, `DialogueManager` ends, `NPC._pick_sequence()` will return `repeat_sequence` on next visit

---

### 3.3 Screen Fade (`res://scripts/screen_fade.gd`)

**Type:** `extends CanvasLayer` — Autoload singleton

Handles black/white fades between scenes. Used for taxi rides (`fade_out` → load scene → `fade_in`) and realm completion (`WHITE` flash). Constants: `BLACK` (dark brown), `WHITE` (warm cream).

---

### 3.4 Global State (`res://scripts/global.gd`)

**Type:** `extends Node` — Autoload singleton

Manages cross-scene state:

| Variable | Type | Description |
|---|---|---|
| `player_current_attack` | `bool` | — |
| `current_scene` | `String` | Current scene name (e.g., `"game"`, `"world cliff_side"`) |
| `transition_scene` | `bool` | Whether a scene transition is in progress |
| `ui_locked` | `bool` | Set when a menu/dialogue is active, preventing player movement |
| `_arrival_pos` | `Vector2` | Where the player should appear in the next scene |
| `_has_arrival_pos` | `bool` | Whether an arrival position has been set |

**Functions:** `set_arrival_pos(pos)`, `has_arrival_pos()`, `take_arrival_pos()` — manage the player's spawn position across scene transitions.

---

### 3.5 Scene Exit (`res://scripts/scene_exit.gd`)

**Type:** `extends Area2D`

Walking into a `SceneExit` area carries the student to another map. Properties: `target_scene` (String, the .tscn file path), `arrival_pos` (Vector2, spawn position in target map). Uses `Global.set_arrival_pos()` and `get_tree().change_scene_to_file.call_deferred()` for deferred scene swapping.

---

### 3.6 NyeMap (`res://scripts/nye_map.gd`)

**Type:** `extends Node2D`

Shared behavior for the three nye map scenes (`drakay_pangtsho`, `tak_tsang`, `jhomo_lhari`). Properties: `map_size` (Vector2, camera bounds), `trek_rooms` (connected camera rooms). On `_ready()`: requests the map's track from the `Music` autoload (`Music.play_for_scene(scene_file_path, name)` — see §3.10), places player at arrival position from `Global`, clamps camera to map size, then calls `ScreenFade.fade_in()`.

---

### 3.7 Ending Sequence (`res://scripts/narrative/ending_sequence.gd`)

**Type:** `extends Node` — Autoload singleton

Manages the final sequence of the retreat. When all realms are complete, the Chorten offers the ending. Transitions to `game.tscn` and plays the ending dream via `DreamOverlay`. After the dream, the player wakes at the household shrine water bowl. Properties: `_ending_active`, `_water_bowl_tended`, `_dream_started`, `_dream_played`, `_transitioning`, `_last_dream_sequence`.

---

### 3.8 Village Opening (`res://scripts/narrative/village_opening.gd`)

**Type:** `extends Node`

The first minute of the retreat. On first visit, plays the dream sequence (`DialogueManager.start(INTRO)`) and applies a cold, drained mood (`CanvasModulate` color). On subsequent visits, skips the dream. Manages the `DialogueManager.dialogue_ended` signal and `DreamOverlay.finished` signal.

---

### 3.9 TileMapLayer Setup

All nye maps use `TileMapLayer` nodes for rendering the game world:

- **`ground` TileMapLayer** — Uses `TileSet_lh53h` (grass, plains, water tiles). No `y_sort_enabled` — renders at a fixed Z-order below the player.
- **`props` TileMapLayer** — Uses `TileSet_props` (objects tiles). Has `y_sort_enabled = true` — sorts props by Y position.
- **`CleanWater` TileMapLayer** — Uses `TileSet_clean_water` (water overlay tiles). No `y_sort_enabled`.

Tile sizes are 16x16 pixels. The `TileSetAtlasSource` configurations define tile positions within atlas textures and `y_sort_origin` values for depth sorting.

---

### 3.10 Music Autoload (`res://scripts/music.gd`)

**Type:** `extends Node` — Autoload singleton

Owns every background music track so no scene needs its own `AudioStreamPlayer` or fade logic. The autoload persists across scene changes, which is what lets a taxi ride keep the departure scene's music playing through the journey; the destination scene requests its own track on load and the crossfade lands under the arrival curtain.

**Track constants:** `TUTORIAL` (tutorial.ogg, village scene), `DREAM` (dream.mp3 — shared by the opening and ending dreams, one sonic identity for both), `LOBBY` (lobby.wav, crossroads), `JOMOLHARI`, `DRAKAY_PANGTSHO`, `TAKTSANG` (the three realm tracks). All files live in `res://assets/audio/music/`.

**Functions:**

| Function | Description |
|---|---|
| `play_track(stream, fade_duration = 1.0)` | Crossfades from whatever is playing to `stream` (old player fades out, new fades in). No-ops if the stream is already the current track — re-entering a scene never restarts the music. `null` fades to silence. |
| `stop_track(fade_duration = 1.0)` | Fades the current track to silence. |
| `play_for_scene(scene_path, root_name = "")` | Plays the track mapped to a scene file / root name. Unmapped scenes (the shrine interiors, the dzong) keep the current track — interiors share their realm's music. |
| `current_track()` | The track playing, or `null`. |
| `active_player()` | The player holding the current track (mainly for tests). |
| `silence_now()` | Stops and frees every player at once (test teardown). |

**Scene wiring:** village (`game.gd`) and lobby (`lobby.gd`) call `Music.play_track(...)` in `_ready()`; the nye maps call `Music.play_for_scene(...)` from `NyeMap._ready()`. The dreams call `Music.play_track(Music.DREAM)` when they begin (`village_opening.gd`, `ending_sequence.gd`) and `village_opening.gd`'s `_after_dream()` fades back to `Music.TUTORIAL` when the student wakes — for both dreams, since they share the `DreamOverlay`.

**Looping:** every provided file ends with an authored fade-out plus a trailing silence pad (up to ~7.2 s). The WAVs loop seamlessly via playback-time `loop_begin`/`loop_end` points measured from the waveforms (the files are untouched); Ogg/MP3 cannot trim their tails (loop-*begin*-only formats), so `dream.mp3`'s ~4.2 s fade-out + silence plays once per repeat — the one known non-seamless loop point (see §7.7). Lead-in pads are skipped via `loop_offset` (`dream.mp3`: 0.595 s).

**Behavior notes:** dialogue does NOT pause music (nothing in the game pauses the tree; the node is `PROCESS_MODE_ALWAYS` anyway). Headless runs (the test harness) skip starting audible playback because the headless audio driver pins played streams for the process lifetime; all track-state logic is identical either way.

---

## 4. Characters

### 4.1 Tashi (Player)

- **Role:** The student on a nature retreat
- **Personality/Speech:** Silent protagonist; communicates through movement and interaction
- **Scene:** `res://scenes/player.tscn` (CharacterBody2D + AnimatedSprite2D)
- **Script:** `res://scripts/player.gd`
- **Controls:** WASD/arrow keys for movement, E/Space/Enter for interact
- **Animation:** `idle_front`, `idle_back`, `idle_side`, `walk_front`, `walk_back`, `walk_side`

### 4.2 The Voice

- **Role:** Narrator/guide who speaks in the dream sequence
- **Personality/Speech:** Ethereal, guiding, speaks in full sentences during the ending dream
- **Scene:** Appears in `res://scenes/ui/dream_overlay.tscn`
- **Script:** `res://scripts/narrative/ending_sequence.gd`

### 4.3 Aum Jomo

- **Role:** NPC at Jomolhari realm; asks for the offering
- **Personality/Speech:** Serene, reverent
- **Scene:** `res://scenes/nyes/aum_jomo.tscn` (Area2D + AnimatedSprite2D + CollisionShape2D + Prompt)
- **Script:** `res://scripts/npc.gd`
- **Dialogue:** `res://dialogue/aum_jomo.tres`
- **Animations:** `aum_jomo_sheet.png` (sprite sheet)

### 4.4 Tshomen

- **Role:** NPC at Drakay Pangtsho realm; asks what is wrong with the lake
- **Personality/Speech:** Concerned, inquisitive
- **Scene:** `res://scenes/nyes/tshomen.tscn` (Area2D + AnimatedSprite2D + CollisionShape2D + Prompt)
- **Script:** `res://scripts/npc.gd`
- **Dialogue:** `res://dialogue/drakay_pangtsho_tshomen_ask.tres`
- **Animations:** `tshomen_sheet.png` (sprite sheet)

### 4.5 Guide

- **Role:** NPC at the lobby crossroads; offers guidance about the realms
- **Personality/Speech:** Knowledgeable, welcoming
- **Scene:** `res://scenes/nyes/guide.tscn` (Area2D + AnimatedSprite2D + CollisionShape2D + Prompt)
- **Script:** `res://scripts/npc.gd`
- **Dialogue:** `res://dialogue/guide_intro.tres`, `res://dialogue/guide_repeat.tres`
- **Animations:** `guide_sheet.png` (sprite sheet)
- **Chorten reference:** `guide_path = NodePath("../Guide")` on the Chorten node

### 4.6 Head Monk (Taktsang)

- **Role:** One of the three keepers of memory at Taktsang
- **Personality/Speech:** Wise, reflective
- **Scene:** `res://scenes/monk.tscn` (Area2D + AnimatedSprite2D + CollisionShape2D + Prompt)
- **Script:** `res://scripts/npc.gd`
- **Animations:** `taktsang_monk.png` (sprite sheet)

### 4.7 Other Monks

- **Role:** Additional keepers at Taktsang (historical, playful, personal)
- **Personality/Speech:** Each has a distinct personality based on their keeper role
- **Scene:** `res://scenes/nyes/tak_tsang.tscn` (instance of `res://scenes/monk.tscn`)
- **Dialogue:** `res://dialogue/taktsang_monk_historical.tres`, `res://dialogue/taktsang_monk_playful.tres`, `res://dialogue/taktsang_monk_personal.tres`

### 4.8 Travelers/Visitors

- **Role:** NPCs at the taxi rank and travel guide
- **Personality/Speech:** Casual, transactional
- **Scene:** `res://scenes/taxi_rank.tscn`, `res://scenes/travel_guide.tscn`

---

## 5. Quest Structure

### 5.1 Jomolhari Realm

**Main Quest:** The Offering at Tsheringma Ney
- **Objective:** Collect offering items (bowl, incense, lamp) and present them at the altar
- **Steps:** 1) Aum Jomo asks for the offering → 2) Collect items → 3) Place items at altar → 4) Realm closes
- **Completion:** `GameState.mark_realm_complete(&"jomolhari")` sets `jomolhari_complete = true`
- **Side Quest:** Additional listening places
- **Script:** `res://scripts/narrative/jomolhari_quest.gd`
- **Dialogue:** `res://dialogue/jhomo_quest_intro.tres`, `res://dialogue/jhomo_altar_waiting.tres`, `res://dialogue/jhomo_altar_offering.tres`, `res://dialogue/jhomo_altar_honoured.tres`, `res://dialogue/jhomo_quest_complete.tres`

### 5.2 Drakay Pangtsho Realm

**Main Quest:** The Disturbed Lake
- **Objective:** Notice visual cues at the water, collect scattered waste, restore the offering stones, and sit at three quiet viewpoints
- **Steps:** 1) Tshomen asks what is wrong with the lake → 2) Examine water → 3) Collect waste items → 4) Restore offering → 5) Sit at viewpoints → 6) Realm closes
- **Completion:** `GameState.mark_realm_complete(&"drakay_pangtsho")` sets `drakay_pangtsho_complete = true`
- **Side Quest:** Listening at viewpoints (North, Center, South)
- **Script:** `res://scripts/narrative/drakay_pangtsho_quest.gd`
- **Dialogue:** `res://dialogue/drakay_pangtsho_quest_intro.tres`, `res://dialogue/drakay_pangtsho_altar_waiting.tres`, `res://dialogue/drakay_pangtsho_altar_offering.tres`, `res://dialogue/drakay_pangtsho_altar_honoured.tres`, `res://dialogue/drakay_pangtsho_quest_complete.tres`, `res://dialogue/drakay_pangtsho_water_noticed.tres`, `res://dialogue/drakay_item_waste_memory.tres`, `res://dialogue/drakay_view_north.tres`, `res://dialogue/drakay_view_center.tres`, `res://dialogue/drakay_view_south.tres`

### 5.3 Taktsang Realm

**Main Quest:** The Three Keepers of Memory
- **Objective:** Listen to three monks' stories (historical, playful, personal) and retell the choice
- **Steps:** 1) Head Monk asks to listen → 2) Listen to three keeper stories → 3) Retell the choice → 4) Realm closes
- **Completion:** `GameState.mark_realm_complete(&"taktsang")` sets `taktsang_complete = true`
- **Side Quest:** —
- **Script:** `res://scripts/narrative/taktsang_quest.gd`
- **Dialogue:** `res://dialogue/taktsang_quest_intro.tres`, `res://dialogue/taktsang_monk_historical.tres`, `res://dialogue/taktsang_monk_playful.tres`, `res://dialogue/taktsang_monk_personal.tres`

---

## 6. Assets

### 6.1 Sprite/Character Assets

| File | Resolution | Format | Usage |
|---|---|---|---|
| `res://assets/sprites/player (1).png` | 48x48 per frame (from larger sheet) | RGBA8 | Player character sprite sheet |
| `res://assets/sprites/aumjomo.png` | — | — | Aum Jomo sprite |
| `res://assets/generated/aum_jomo.png` | — | — | Aum Jomo sprite |
| `res://assets/generated/aum_jomo_sheet.png` | — | — | Aum Jomo animation atlas |
| `res://assets/generated/tshomen.png` | — | — | Tshomen sprite |
| `res://assets/generated/tshomen_sheet.png` | — | — | Tshomen animation atlas |
| `res://assets/generated/guide.png` | — | — | Guide sprite |
| `res://assets/generated/guide_sheet.png` | — | — | Guide animation atlas |
| `res://assets/generated/taktsang_monk.png` | — | — | Taktsang monk sprite |
| `res://assets/generated/drakay_pangtsho_monk.png` | — | — | Drakay Pangtsho monk sprite |
| `res://assets/generated/bhutan_house.png` | — | — | Bhutanese house prop |
| `res://assets/generated/dzong.png` | — | — | Dzong (monastery) prop |
| `res://assets/generated/boulder.png` | — | — | Boulder prop |
| `res://assets/generated/pine_tree.png` | — | — | Pine tree prop |
| `res://assets/generated/prayer_flags.png` | — | — | Prayer flags prop |
| `res://assets/generated/water_bowl.png` | — | — | Water bowl prop/item |
| `res://assets/generated/stupa.png` | — | — | Stupa prop |
| `res://assets/generated/temple_lhakhang.png` | — | — | Temple/lhakhang prop |
| `res://assets/generated/rock_tile.png` | — | — | Rock tile for TileMap |
| `res://assets/generated/snow_rock_tile.png` | — | — | Snow rock tile for TileMap |

### 6.2 Tileset Assets

| File | Resolution | Format | Usage |
|---|---|---|---|
| `res://assets/tilesets/grass.png` | 16x16 | — | Ground tile (source 0 in TileSet_lh53h) |
| `res://assets/tilesets/plains.png` | 96x192 | — | Plains tiles (source 1 in TileSet_lh53h, 6x12 grid) |
| `res://assets/generated/water_tile.png` | 16x16 | — | Water tile (source 2 in TileSet_lh53h, and TileSet_clean_water) |
| `res://assets/tilesets/objects/objects.png` | 256x208 | — | Objects tileset (TileSet_props, 16x13 grid) |
| `res://assets/tilesets/decor_8x8.png` | — | — | Decor tiles (8x8) |
| `res://assets/tilesets/decor_16x16.png` | — | — | Decor tiles (16x16) |
| `res://assets/tilesets/fences.png` | — | — | Fence tiles |
| `res://assets/tilesets/floors/flooring.png` | — | — | Flooring tiles |
| `res://assets/tilesets/floors/carpet.png` | — | — | Carpet tiles |
| `res://assets/tilesets/floors/wooden.png` | — | — | Wooden floor tiles |

**Convention:** All tiles are 16x16 pixels unless otherwise noted. Sprite sheets use RGBA8 format with transparent backgrounds. Animation atlases use `SpriteFrames` resources (.tres) with `mode:"generated_atlas"` for Ziva-generated animations.

### 6.3 Dialogue Assets

Dialogue sequences are stored as `DialogueSequence` resources (.tres) in `res://dialogue/`. Each contains an array of `DialogueLine` resources. Examples include quest intros, altar dialogues, water-noticed dialogues, and repeat sequences.

### 6.4 Audio Assets

Background music/ambience (this pass covers music only; SFX are handled separately):

| File | Format | Length | Usage |
|---|---|---|---|
| `res://assets/audio/music/tutorial.ogg` | Ogg Vorbis, 44.1 kHz stereo | ~196 s | Village / tutorial scene |
| `res://assets/audio/music/dream.mp3` | MP3, 44.1 kHz stereo | ~119 s | Opening dream and ending dream (shared track) |
| `res://assets/audio/music/lobby.wav` | WAV (QOA import), 44.1 kHz stereo | ~159 s | Crossroads / lobby scene |
| `res://assets/audio/music/jomolhari.wav` | WAV (QOA import), 44.1 kHz stereo | ~163 s | Jhomo Lhari realm |
| `res://assets/audio/music/drakeypangtsho.wav` | WAV (QOA import), 44.1 kHz stereo | ~161 s | Drakay Pangtsho realm |
| `res://assets/audio/music/taktsang.wav` | WAV (QOA import), 44.1 kHz stereo | ~108 s | Taktsang realm |

Looping is configured at playback time by the `Music` autoload (`res://scripts/music.gd`), not in the `.import` files — see §3.10. All files were authored with an ending fade-out plus a trailing silence pad; the WAV loop points trim that pad out of the loop.

---

## 7. Known Gaps and TODOs

### 7.1 Placeholder Assets

- `tshomen_sheet.png` and `guide_sheet.png` are generated placeholder art. Actual sprite sheet art is needed for guide (grey-haired character with magenta tunic) and tshomen (mermaid + male character). The `generate_image` tool is currently unavailable (monthly spending limit exceeded).
- Some `assets/generated/*.png` files may be generated placeholders rather than final art.

### 7.2 TileMap Ground Layer

- The `ground` TileMapLayer in `drakay_pangtsho.tscn` was previously missing during development. It has been restored with `TileSet_lh53h` and `tile_map_data`. The `tile_map_data` was initially generated with a format that caused "Corrupted tile map data" warnings but was later fixed by using the `props` `tile_map_data` format as a template.

### 7.3 Resource Cleanup

- The test harness used to report `ERROR: N resources still in use at exit`. The audio-related cause is resolved: Godot's headless audio driver pins any stream ever `play()`ed for the process lifetime, so the `Music` autoload skips starting audible playback in headless runs (see §3.10). The latest full suite run reports no such errors.

### 7.4 Push Warnings

- `game_state.gd` contains `push_warning` calls in `mark_realm_complete` and `is_realm_complete` that fire when unknown realm names are passed. These are informational warnings for the `test_unknown_realms_are_ignored` test case, not errors.

### 7.5 Frame Progress

- `frame_progress` values were removed from `aum_jomo.tscn`, `tshomen.tscn`, and `guide.tscn` to fix Z-order rendering issues with the `AnimatedSprite2D` nodes.

### 7.6 Scene Validation

- All `.tscn` files should be validated in the Godot Editor after modifications to ensure no parse errors.

### 7.7 Music loop tails

- Every provided music file ends with an authored fade-out plus a pad of silence (drakeypangtsho ~7.2 s, taktsang ~3.2 s, dream ~4.2 s, lobby ~2.1 s, jomolhari ~1.8 s, tutorial ~0.24 s). The `Music` autoload trims this pad out of the loop for the four WAVs via playback-time `loop_begin`/`loop_end` points, so they loop seamlessly.
- **dream.mp3 cannot be trimmed at playback time** — Ogg and MP3 formats only support a loop *begin* offset, not a loop end — so the dream track dips through its ~4.2 s authored fade-out + silence once per repeat. If that bothers the dream's long holds, the file needs re-encoding with the tail cut; the audio file itself was deliberately left unmodified. Its 0.6 s lead-in *is* skipped (`loop_offset = 0.595`). `tutorial.ogg` has a mild 0.24 s fade-down with the same limitation.
- No audible clicks exist at any loop seam (start/end samples match to ~zero in every file).

---

## Test Results

Current suite: **147 tests across 18 files — 142 pass, 5 known pre-existing failures**:

- `test_dialogue.gd`
- `test_drakay_pangtsho_quest.gd`
- `test_ending_sequence.gd`
- `test_game_state.gd`
- `test_herder_quest.gd`
- `test_jomolhari_quest.gd`
- `test_lobby_return_beat.gd`
- `test_mending_quest.gd`
- `test_monk.gd`
- `test_music.gd` (9 tests — Music autoload: same-track guard, crossfade structure, scene/root-name mappings, interiors inheriting, loop setup)
- `test_pilgrim_quest.gd`
- `test_project_setup.gd`
- `test_prop_sorting.gd` (2 failures — `game.tscn` tile art metrics: `objects.png` atlas (0,5) sort origin and trunk collision; unrelated to audio)
- `test_scene_transitions.gd`
- `test_shrine.gd`
- `test_taktsang_quest.gd` (3 failures — the retell-choice UI renders no buttons; pre-dates the music pass and occurs with the music code disabled too)
- `test_taxi_rank.gd`
- `test_village_opening.gd`

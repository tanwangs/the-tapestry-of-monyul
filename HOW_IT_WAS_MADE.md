# How It Was Made — The Tapestry of Monyul

> A build narrative for each core system of the game, written as source
> material for the project documentation. Every section names the actual
> files, nodes and constants involved, and explains not just *what* was built
> but *why* it was built that way. For a pure API reference, see
> `IMPLEMENTATION.md`; for a project overview, see `DOCUMENTATION.md`.

---

## Table of Contents

1. [The Player — Movement, Collision, Animation](#1-the-player--movement-collision-animation)
2. [The Maps — TileLayers, Y-Sorting, Camera](#2-the-maps--tilelayers-y-sorting-camera)
3. [Interaction — Dialogue and the Dialogue Box](#3-interaction--dialogue-and-the-dialogue-box)
4. [Map-to-Map Transitions](#4-map-to-map-transitions)
5. [The Addition of Music](#5-the-addition-of-music)

---

## 1. The Player — Movement, Collision, Animation

**Scene:** `res://scenes/player.tscn` — **Script:** `res://scripts/player.gd`

### 1.1 The node tree and why it is built this way

```
Player (CharacterBody2D) [y_sort_enabled=true]
├── world_camera (Camera2D) [zoom=Vector2(4,4), limit_* = old world map bounds]
├── lobby_camera (Camera2D)      (kept as a node, unused by current scenes)
├── AnimatedSprite2D [position=(0,-21), y_sort_enabled=true]
└── CollisionShape2D [position=(0,-5)]
```

The player is a `CharacterBody2D` rather than a `RigidBody2D` because the
student never needs physics simulated — only walked. The camera is a *child
of the player* so it follows for free, but it is a separate node (not the
player itself) because the taxi system later *re-parents that camera onto the
taxi* during a ride (`TaxiRank.board_passenger()`), then hands it back. That
trick is only possible because the camera was never baked into the player's
own transform.

The player is added to the group `"player"` in `_ready()`. This group is the
backbone of nearly every interaction in the game: exit areas, NPC proximity,
taxi boarding, quest triggers — they all ask "is this body in the `player`
group?" rather than checking for the player by name or path, so scenes stay
decoupled.

### 1.2 Movement

Movement lives entirely in `_physics_process()` (`player.gd`), with two
constants:

```gdscript
const SPEED: float = 100.0   # pixels per second
```

The input is read with `Input.get_vector(...)`, which Godot normalizes
automatically, so diagonal walking is not faster. Two action sets are tried in
order, either of which works on its own:

1. `"ui_left"/"ui_right"/"ui_up"/"ui_down"` — the built-in Godot actions
   (WASD + arrow keys), so movement works with zero project configuration.
2. `"move_left"/...` — the project's own custom actions, defined in
   `project.godot`'s Input Map, as a fallback.

Velocity is simply `direction * SPEED`, handed to `move_and_slide()`, which is
called every frame even when velocity is zero. Keeping `move_and_slide()` on
idle frames matters: it keeps the physics state consistent (floor detection,
collision normal updates) so the world never "catches up" in a surprising way
when the student starts moving again.

**The dialogue lock** is the first thing `_physics_process` checks:

```gdscript
if DialogueManager.is_active or Global.ui_locked:
    velocity = Vector2.ZERO
    _animate(false)
    move_and_slide()
    return
```

Two different locks exist, both honored by the player:

- `DialogueManager.is_active` — a conversation is on screen.
- `Global.ui_locked` — any other full-screen moment (a taxi ride, the dream,
  the travel menu) that needs the student to stand still.

In both cases movement is zeroed *rather than skipping the frame entirely* —
the student still animates her idle pose and physics still steps.

### 1.3 Collision

Collision is the sum of three separate sources, which is deliberate:

1. **The player's own `CollisionShape2D`** — a small capsule/rectangle near
   the feet (offset to `(0, -5)` so the visual body overlaps scenery while the
   physical body stays near the ground line).
2. **The map's `collisions` `StaticBody2D`** — each scene carries a node
   holding one or more `CollisionPolygon2D` nodes hand-drawn around the
   un-walkable geometry (cliff faces, buildings, water edges). These are
   authored in the editor by tracing the map art.
3. **Tile collision on the props layer** — see §2.3: tall multi-cell props
   (trees, big rocks) carry their own trunk collision inside the TileSet, so
   the student is stopped at the trunk while the canopy draws over her head.

Because `move_and_slide()` handles the resolution, no collision code exists in
`player.gd` at all — the engine pushes the student out of shapes; the script
only decides velocity.

### 1.4 Animation

The student's artwork is a single sprite sheet, `res://assets/sprites/player
(1).png`, sliced at build time into six named animations. Every frame is
48×48 px, arranged in rows; each row becomes one animation:

| Animation | Row in the sheet | Frames |
|---|---|---|
| `idle_front` / `walk_front` | y=96 / y=144 | 6 each |
| `idle_side` / `walk_side` | y=48 / y=240 | 6 each |
| `idle_back` / `walk_back` | y=0 / y=192 | 6 each |

The slicing is done with `AtlasTexture` sub-resources — one per frame — each
pointing at a `Rect2` region of the shared sheet, wrapped in a `SpriteFrames`
resource at 10 frames per second. One shared texture, many small regions: no
duplicated pixels, and the whole character is one import.

Facing is derived in `_animate(moving)` from the movement direction of the
last non-zero input, and only ever holds four values: `up`, `down`, `left`,
`right`. The side sprite is *one* animation — `flip_h` mirrors it for left —
so the sheet needs only one walk-cycle pair for sideways movement:

```gdscript
_sprite.flip_h = _facing == "left"
_sprite.play(("walk_" if moving else "idle_") + suffix)
```

---

## 2. The Maps — TileLayers, Y-Sorting, Camera

Every playable landscape (`game.tscn`, `lobby.tscn`, and the three nye maps
`nyes/drakay_pangtsho.tscn`, `nyes/tak_tsang.tscn`, `nyes/jhomo_lhari.tscn`)
is built from the same recipe of TileMapLayer nodes plus hand-placed sprites.
Godot 4.3+ uses one `TileMapLayer` node per role (the old single `TileMap`
with numbered layers is gone), and the project leans into that.

### 2.1 The layer recipe

```
<map root> (Node2D) [y_sort_enabled=true]  ← script: nye_map.gd (nyes) or game.gd/lobby.gd
├── ground  (TileMapLayer)   base terrain, never y-sorted
├── cliff   (TileMapLayer)   backdrop / cliff band, never y-sorted
├── yset    (TileMapLayer)   or "props": the y-sorted prop layer
├── collisions (StaticBody2D) + CollisionPolygon2D
├── Player, NPCs, exit areas, quest nodes ...
```

- **`ground`** draws the walkable surface — grass, plains, snow, water — and
  sits below everything. It has no `y_sort_enabled`, because terrain *is* the
  floor: it must never interleave with characters.
- **`cliff`** is the non-interactive backdrop band (rock faces behind the
  map), also un-sorted.
- **`yset` / `props`** is where trees, bushes, rocks, fences and buildings
  live. It has `y_sort_enabled = true` **and stays in the default z-index
  band (0)**. That second rule is load-bearing: Godot only y-sorts items in
  the same z band, so hoisting the prop layer to `z_index = 1` would draw the
  canopy over the student *everywhere* and silently break the "walk behind
  the tree" look (guarded by the test
  `test_ysorted_prop_layers_stay_in_the_default_z_index_band`).
- **`CleanWater`** (Drakay Pangtsho only) is a ground-level overlay that is
  invisible until the lake is restored; the quest script toggles
  `_clean_water_layer.visible = finished` in `_refresh()`.

### 2.2 TileSets and tile data

Each layer's TileSet holds several `TileSetAtlasSource` entries — one per
texture (`grass.png`, `plains.png`, `rock_tile.png`, `objects.png`, ...), all
16×16 px tiles. The tiles themselves are stored in the scene as
`tile_map_data`, a `PackedByteArray` that encodes, for every placed cell:
`pos_x, pos_y` (int16) and `tile_id, source_id` (uint16), behind a small
header. Editing is done through Godot's tile editor; the bytes are only ever
read by the engine.

### 2.3 Y-sorting tall props — the one genuinely fiddly part

A multi-cell prop (a 2×4 tree, say) must sort as if it were a sprite *standing
on the ground*, not as a grid of tiles. Two authored properties make that
work, both stored in the TileSet atlas:

1. **`y_sort_origin`** — the distance from the tile's top edge down to where
   the artwork visually meets the ground (e.g. 14 for a bush, 64 for a tall
   tree). With `y_sort_enabled` on the layer, Godot sorts each prop by this
   line, so the whole tree is drawn behind or in front of the student
   depending on where her feet are — the "hidden behind the tree while
   standing at its trunk" effect. `test_props_sort_by_the_base_of_their_art`
   guards this: every tall tile's `y_sort_origin` must equal the distance from
   the region's top to the base of its art.
2. **Physics polygon offset** — TileSet collision polygons are positioned
   relative to the *center of the prop's origin cell* (the top-left cell of
   its region), not the center of the full region. The trunk polygons were
   therefore authored pre-shifted by
   `((width_cells - 1) * 8, (height_cells - 1) * 8)` — half a tile per extra
   cell, for 16 px tiles — so the collision hugs the trunk. Without the
   shift, the collision floats up into the canopy and stops the student
   above the base line while Y-sorting draws the whole tree over her.
   `test_tall_tile_collision_hugs_the_art_base` guards this invariant.

Static scenery *not* in the tilemap (stupas, temples, houses) is plain
`Sprite2D` nodes; the NPC script's sprite placement uses the same principle
(§3.2).

### 2.4 The camera and the shared map script

All three nye maps share `res://scripts/nye_map.gd` (`class_name NyeMap`),
which was extracted once and reused rather than copied per map:

- `@export var map_size` clamps the camera to the map rectangle
  (`limit_left/top/right/bottom`), so the view never runs off the edge.
- `@export var trek_rooms: Array[Rect2]` supports the continuous taktsang
  trail: as the student walks, the camera re-limits itself to whichever room
  she is inside, room by room.
- `_ready()` also places the player wherever the previous map handed her over
  (§4.2) and fades the curtain back in.

---

## 3. Interaction — Dialogue and the Dialogue Box

The interaction system is deliberately split into three layers that know
nothing about each other: **data** (DialogueSequence resources), **logic**
(the DialogueManager autoload), and **looks** (the DialogueBox scene). A
conversation can be written, tested, or re-skinned without touching either of
the other two.

### 3.1 Data — `res://scripts/dialogue/dialogue_line.gd` and `dialogue_sequence.gd`

A conversation is a `.tres` resource (in `res://dialogue/`) holding an array
of `DialogueLine` resources:

- `speaker: String`, `text: String` (multiline, `{player}` placeholder),
  `portrait: Texture2D` (optional), `choices: PackedStringArray` (optional —
  a choice line ends the conversation when answered).
- The sequence carries a stable `id: StringName` so scripts can react to
  "this exact conversation just finished" in `dialogue_ended`.

Because conversations are data, writing a new one is authoring a file, not
writing code.

### 3.2 The talkable — `res://scripts/npc.gd` (`class_name NPC extends Area2D`)

Every character, offering item, listening place, marker and the shrine is an
NPC. It is an `Area2D`, which gives proximity for free through physics
signals:

```
NPC (Area2D) [y_sort_enabled=true, groups="npc"]
├── Sprite2D (still art) or AnimatedSprite2D (animated art)
├── CollisionShape2D (CircleShape2D, radius 34.0)
└── Prompt (Label)
```

- **Proximity:** `body_entered`/`body_exited` set `_player_nearby` when a
  body in the `"player"` group crosses the circle. The floating "!" prompt is
  shown when `has_talk()` is true, and gently bobs in `_process` so it reads
  as a button, not scenery.
- **Static sprite placement:** when a still `Sprite2D` is used, the script
  positions the art so the node's *origin* sits on the art's ground-contact
  line (`_sprite.position = (0, -height/2)`). Y-sorting then works exactly as
  it does for the tall props in §2.3 — the student disappears behind the
  body of a stupa but walks in front of its base.
- **Two artworks, one script:** `_sprite` and `_animated` are both looked up
  with `get_node_or_null()`; whichever exists is used, and `play_animation()`
  safely does nothing when the character has no frames — so callers can ask
  freely.
- **First visit vs. repeat:** `_pick_sequence()` asks
  `GameState.first_time(key)` — full `sequence` on first meeting, short
  `repeat_sequence` afterwards. The `key` defaults to the node's own path, so
  nameless markers "just work". One refinement: when a quest swaps in a
  *brand-new* full conversation (a guide's answer to work just finished),
  it is heard out exactly once before the repeat takes over again — tracked
  as `key + "/" + sequence.id` in `GameState.seen_lore`.

### 3.3 The hub — `res://scripts/dialogue_manager.gd` (autoload)

The `DialogueManager` holds *only* conversation state, and announces every
change with signals; it never draws anything:

- `start(sequence)` — refuses if a conversation is already running or the
  sequence is empty; emits `dialogue_started` then the first `line_changed`.
- `advance()` — next line, or `dialogue_ended` after the last. On a choice
  line it refuses: choices wait for `choose()`.
- `choose(index)` — records `last_choice`, ends the conversation so the
  starter can react (the Taktsang retell uses this).
- `is_active` — the flag the player script and every prompt check.

The signal-driven split means any number of things can listen to a
conversation (the box, quest scripts that react to specific sequence ids,
tests) without the manager knowing they exist.

### 3.4 The looks — `res://scenes/ui/dialogue_box.tscn` / `dialogue_box.gd`

A `CanvasLayer` (layer 20) with a bottom-anchored panel. It listens to the
three manager signals and:

- Reveals text **one character at a time** at
  `CHARS_PER_SECOND = 45.0` — the `substr(0, int(_revealed))` typewriter.
- Pressing the talk key (or `ui_accept`) **first completes the line** if it
  is still typing, and only advances on the *second* press — the standard
  visual-novel pacing. `_accepts_input` is false for the first frame so the
  key press that *opened* the box cannot also skip its opening line.
- A blinking `▼` indicator appears when the line is done.
- `{player}` in speaker and text is replaced with `GameState.player_name`.
- **Choice lines** grow the box taller (`BOX_TOP_CHOICES`) and build one
  `Button` per offered answer between the text and the arrow; the first
  button grabs keyboard focus so arrows/E work without a mouse. A press
  calls `DialogueManager.choose(index)`.

One `DialogueBox` instance lives in each map scene, so the interface is
destroyed and recreated with the world — but that is free, because all state
lives in the manager.

### 3.5 How a talk actually starts

The player script is the only place that decides *who* gets talked to. On
`interact` pressed, `_unhandled_input` scans in priority order:

1. `_nearest_water()` — the nearest node in group `"drayay_water"` within
   `TALK_RANGE` (60 px) — the Drakay lake is an `Area2D`, not an NPC.
2. `_nearest_boardable_rank()` — a taxi whose boarding area the student is
   standing in (`TaxiRank.can_board()`).
3. `_nearest_talkable()` — the closest NPC in group `"npc"` for which
   `has_talk()` is true.

Each scan is "closest within range, currently willing", and the winner's
`interact()` is called. Because it is `_unhandled_input`, menus drawn on top
that handle the key first naturally block the world behind them.

---

## 4. Map-to-Map Transitions

All scene changes funnel through the same pattern: **the leaving map sets a
hand-over (where to stand), the engine swaps the scene, and the arriving map
consumes the hand-over in `_ready()`.** The `Global` autoload
(`res://scripts/global.gd`) carries the envelope:
`set_arrival_pos()` / `has_arrival_pos()` / `take_arrival_pos()`, plus
`current_scene` ("game"/"lobby") and the `transition_scene` flag.

### 4.1 Walking out — `res://scripts/scene_exit.gd`

An `Area2D` with two exports, `target_scene` and `arrival_pos`. When the
player body enters:

```gdscript
_leaving = true   # the overlap fires more than once; guard it
Global.set_arrival_pos(arrival_pos)
get_tree().change_scene_to_file.call_deferred(target_scene)
```

The `call_deferred` is essential, not stylistic: swapping scenes frees the
very collision shapes Godot is still walking through for this overlap
callback, which the engine forbids mid-physics-step. The exits form a trail
between the three nyes (Drakay ↔ Jhomo Lhari ↔ Taktsang) so the retreat can
be walked end to end.

### 4.2 Arriving — the shared `_ready()` pattern

Every scene root's `_ready()` does the same three steps (in `game.gd`,
`lobby.gd`, `nye_map.gd`):

1. Declare itself: `Global.current_scene = "game"/"lobby"` — so either
   scene runs on its own, not just from the other.
2. Consume the envelope: if `Global.has_arrival_pos()`, stand the player
   there and clear it.
3. Bring the curtain up: `ScreenFade.fade_in()`.

### 4.3 The curtain — `res://scripts/screen_fade.gd` (autoload)

A `CanvasLayer` at layer 100 holding a full-screen `ColorRect`, tweened in
alpha. It offers `fade_out`/`fade_in` (black, `Color(0.04, 0.03, 0.03)`),
`fade_out_to(WHITE)` (a warm cream for state-changes, not journeys),
`blacken`, and `show_message()` — words written across the curtain
("Taxi arriving...", "The connection grows stronger..."). It is
`PROCESS_MODE_ALWAYS` so it keeps animating while gameplay is locked. Every
transition therefore reads as a curtain, never a hard cut.

### 4.4 The village ↔ lobby doorway (the flag-based change)

The village's east doorway and the lobby's west doorway swap the two scenes
back and forth using the `transition_scene` flag rather than calling
`change_scene_to_file` directly from a physics callback:

- The doorway `Area2D` sets `Global.set_arrival_pos(...)`, then
  `Global.transition_scene = true`.
- Each scene's `_process` watches the flag, and when *its own*
  `current_scene` matches, performs `get_tree().change_scene_to_file(...)`
  and calls `Global.finish_changescenes()` (which flips "game" ↔ "lobby").
- Neither doorway can bounce the student straight back: the village's
  doorway cancels the flag when she steps out of it again, and the lobby's
  west doorway only arms once she has been outside it.

The flag indirection also serves the ending: while the ending dream is
waiting to play, `game.gd` checks the EndingSequence's state *inside* this
same `_process` and refuses the change of scene, because the dream overlay
lives in the game scene.

### 4.5 The taxi (the third kind of transition)

The taxi system (`res://scripts/travel/taxi_rank.gd` +
`res://scripts/travel/travel_destination.gd`) was built on top of the same
envelope pattern, as one shared script used by every rank in every location:

- **Destinations are data**: a `TravelDestination` resource per place
  (`label`, `icon`, `blurb`, `realm`, `scene_path`, `arrival_pos`,
  `taxi_stop_path`) — the menu is built from a list of them.
- **The ride out:** the shrine dispatches the taxi (`dispatch_outbound`);
  it tweens in along an approach lane; E boards through the taxi's own
  `BoardArea` (not the post's talk circle — the taxi parks `lane_offset`
  clear of the post). Boarding locks UI, hides the player, re-parents her
  `world_camera` onto the taxi (§1.1), and tweens the taxi off-screen before
  `ScreenFade.fade_out()` and the scene change.
- **The hand-over:** before the change, `Global.begin_taxi_arrival(stop_path)`
  records the destination's stop node path *relative to the destination
  scene's root*. The rank it names claims the trip in its own `_ready`
  (resolving the path by node, not string comparison, so relative and
  absolute paths both work); any rank that finds a still-pending trip warns
  and drops it, so a typo can never strand a trip in a later scene.
- **The arrival:** `_play_arrival()` drives the taxi in with the hidden
  student, pauses ~1.4 s at the post, then steps her out *exactly where the
  taxi stands* — a zero-motion camera handoff, because taxi, student and
  camera all share one position at that moment. Handing the camera back
  after the taxi departs instead would drag the camera to the map's clamped
  edge behind the taxi and snap it back.

---

## 5. The Addition of Music

The most recent system, added without touching any existing scene's
structure. **Script:** `res://scripts/music.gd`, registered as the `Music`
autoload in `project.godot`. All six provided files live in
`res://assets/audio/music/` (one per scene plus the shared dream track).

### 5.1 One autoload, one decision: why `play_track` looks the way it does

The brief was: background music/ambience for the whole game, crossfaded
between tracks, with track-switching logic in *one* place. Everything else
followed from making the autoload own it:

- **Crossfade:** `play_track(stream, fade_duration = 1.0)` hands the old
  player to a fade-out tween (SINE-eased `volume_db` from 0 toward −60 dB)
  while a fresh player fades in from −60 dB toward 0. Players are
  one-shot — a retired player frees itself when its fade lands — and each
  player is allowed at most one live tween, so two fades can never fight
  over one volume.
- **The same-track guard:** asking for the track that is already current
  returns immediately, so re-entering a scene never restarts its music.
- **Scene mapping:** `play_for_scene(scene_path, root_name)` maps the three
  nye maps to their tracks by file path *and* by root node name (for
  instanced maps). **Unmapped scenes — the shrine and dzong interiors —
  are deliberately unmapped**, so they inherit their realm's track instead
  of cutting or restarting it.
- **Persistence is the taxi answer:** the autoload survives scene changes,
  so a taxi ride keeps the departure scene's music playing through the
  drive for free; the destination scene asks for its own track in `_ready()`
  and the crossfade lands under the arrival curtain. This is the
  *persist-through-journey* approach, chosen over fading to silence
  precisely because it needs no taxi code at all.

### 5.2 The wiring (every call site)

| Moment | Call |
|---|---|
| Village loads | `game.gd` `_ready()` → `Music.play_track(Music.TUTORIAL)` |
| Lobby loads | `lobby.gd` `_ready()` → `Music.play_track(Music.LOBBY)` |
| Nye map loads | `NyeMap._ready()` → `Music.play_for_scene(...)` |
| A dream begins | `village_opening.gd` / `ending_sequence.gd` `_start_dream()` → `Music.play_track(Music.DREAM)` — one track for both dreams, per the story's intent that the two moments share a sonic identity |
| The student wakes | `village_opening.gd` `_after_dream()` → back to `Music.TUTORIAL` — runs for both dreams, since both play through the same `DreamOverlay` |

Dialogue never pauses the music (nothing in the game pauses the tree; the
node is `PROCESS_MODE_ALWAYS` anyway), so each scene's track keeps breathing
under conversations, per the ambient design.

### 5.3 The loop measurements — data before guessing

Every provided file was decoded and its seam measured before writing the loop
setup. Findings:

- **No clicks anywhere**: last and first samples match to ~zero in all six
  files.
- **Every file ends with an authored fade-out plus a trailing silence pad**:
  drakeypangtsho ~7.2 s, taktsang ~3.2 s (+0.15 s lead-in), dream ~4.2 s
  (+0.6 s lead-in), lobby ~2.1 s, jomolhari ~1.8 s, tutorial ~0.24 s. Looping
  the raw file would breathe a silent dip into the ambience on every repeat.

The loop is therefore configured at **playback time** (the `.import` files
and audio files untouched):

- **WAVs** get `loop_mode = LOOP_FORWARD` plus measured
  `Vector2i(loop_begin, loop_end)` points in samples (44.1 kHz), trimming the
  fade-out and pad out of the loop entirely — all four loop seamlessly,
  carrying sound right up to the seam.
- **Ogg/MP3 support only a loop *begin* offset**, not a loop end — their
  tails cannot be trimmed at playback time. `dream.mp3`'s 0.6 s lead-in is
  skipped via `loop_offset = 0.595`, but its ~4.2 s authored tail still
  plays once per repeat — the one known non-seamless loop point, fixable
  only by re-encoding the file (the file was deliberately not modified).

### 5.4 One platform quirk handled, and the tests

During verification the headless test harness reported
`ERROR: N resources still in use at exit` and flipped suite verdicts. The
cause, isolated by experiment: Godot's headless audio driver pins any
stream ever `play()`ed for the process lifetime — `stop()`, clearing the
stream, even freeing the player does not release it. The fix: `Music` skips
starting audible playback when `DisplayServer.get_name() == "headless"`;
the game always runs with a real audio driver, and all track-state logic is
identical either way.

`res://tests/test_music.gd` (9 tests) asserts on the hand-off *structure*
(who holds which track, which fades are scheduled, what the mappings return)
rather than audible playback, and tears down with `Music.silence_now()` so
no stream is left referenced between tests.

---

## Cross-cutting patterns worth keeping in the documentation

1. **Groups over references.** `"player"` and `"npc"` groups decouple every
   system; nothing reaches for another node by path unless it owns it.
2. **Signals over calls.** DialogueManager, TaxiRank's `arrival_completed`,
   DreamOverlay's `finished` — systems announce; whoever cares listens.
3. **Data over code.** Dialogue, taxi destinations, tile placements: all
   resources, all editable without scripts.
4. **One shared script per repeated shape.** `NyeMap` for the three nyes,
   `NPC` for every character, `TaxiRank` for every rank, `SceneExit` for
   every doorway.
5. **The envelope pattern for transitions.** Leave: set the hand-over;
   arrive: consume it in `_ready()`. Walking, taxi and ending all reuse it.
6. **Autoloads own cross-scene state and singletons that must survive
   changes** (`Global`, `GameState`, `ScreenFade`, `DialogueManager`,
   `Music`, `EndingSequence`) — and nothing else lives outside scenes.
7. **Tests guard the invariants that are easy to break silently** — tile
   sort origins, collision polygon shifts, z-index bands, the music mappings.

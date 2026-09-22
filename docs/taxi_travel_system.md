# Taxi Travel System

The Tapestry of Monyul moves between its maps with a shared roadside taxi.
One rank scene (`scenes/taxi_rank.tscn`) plus one script
(`scripts/travel/taxi_rank.gd`) serve every location; the only per-map work is
placement and a list of destination resources.

## Contents

- [At a glance](#at-a-glance)
- [The pieces](#the-pieces)
- [The two journeys](#the-two-journeys)
- [The shared arrival beat](#the-shared-arrival-beat)
- [The scene hand-over](#the-scene-hand-over)
- [Boarding and input](#boarding-and-input)
- [Configuring a rank](#configuring-a-rank)
- [Adding a new destination](#adding-a-new-destination)
- [Edge cases and rules](#edge-cases-and-rules)
- [Related travel that is *not* the taxi](#related-travel-that-is-not-the-taxi)
- [Tests](#tests)

## At a glance

- **Outbound** (Base Camp → realm): the shrine (*Chorten*) dispatches the taxi
  with `dispatch_outbound()`. It drives in, the student boards with **E**, and
  the ride ends with the arrival beat at the destination's own rank.
- **Return** (realm → Base Camp): the student stands at the post and presses
  **T** to call, boards with **E** once it stops, and the lobby's rank
  (`LobbyTaxiStop`) plays the same arrival beat.
- Every arrival — either direction — follows one routine: the taxi drives in
  with the (hidden) student aboard, stops at the post, pauses briefly, then
  drives off-screen leaving the student standing at the stop.

## The pieces

| File | Role |
|---|---|
| `scripts/travel/taxi_rank.gd` (`class_name TaxiRank`, extends `NPC`) | The whole taxi behaviour: calling, dispatching, driving in, boarding, the ride out, and the arrival beat. |
| `scenes/taxi_rank.tscn` | The rank: post sprite, talk circle, hidden `Taxi` node (sprite + `BoardArea` + "Get in" hint), and a `TravelMenu` instance. Instanced into every map. |
| `scripts/travel/travel_destination.gd` (`class_name TravelDestination`) | One place the taxi can carry the student, as a `.tres` resource in `res://travel/`. |
| `scenes/ui/travel_menu.tscn` + `travel_menu.gd` (`class_name TravelMenu`) | The destination picker. Buttons are built from whatever list the rank hands it. |
| `scripts/narrative/chorten.gd` (`class_name Chorten`) | The shrine at the crossroads: offers the realm menu and dispatches the lobby's taxi. |
| `scripts/travel/travel_guide.gd` (`class_name TravelGuide`) | The lobby guide; his `finished_talking` signal opens the rank's / shrine's menu. |
| `scripts/global.gd` (autoload `Global`) | Persists the pending trip and arrival position across the scene swap. |
| `scripts/player.gd` | Routes the **E** key: a boardable taxi is found by the taxi's own position, not the post. |

## The two journeys

### Outbound: Base Camp → realm

1. The student talks to the shrine (or the guide's introduction ends, which
   opens the menu via `guide_path`).
2. `Chorten.open_menu()` shows the realm menu. On a choice it finds
   `LobbyTaxiStop` in the current scene and calls
   `dispatch_outbound(destination)`.
   - `dispatch_outbound()` returns `false` if a taxi is already driving in —
     the choice is not lost, the player just gets "The taxi is already on its
     way."
   - If a taxi is already *waiting* at the stop, the plan simply changes: the
     student can board the same taxi for the newly chosen destination.
   - `LobbyTaxiStop` has `allow_manual_call = false`, so it only ever serves
     dispatched trips.
3. `_send_in()` places the taxi at `lane_offset + approach_offset` (off-screen
   to the west), shows "Taxi arriving...", and tweens it to `lane_offset` over
   `drive_time` seconds, facing its direction of travel.
4. The student boards with **E** (`board_passenger`): control off
   (`Global.ui_locked`), artwork hidden, camera reparented onto the taxi, and
   the taxi tweens off-screen to the east over `leave_time * DEPART_REACH`.
5. `_finish_trip()` fades out, records the hand-over in `Global` (see
   [below](#the-scene-hand-over)), and changes scene.

### Return: realm → Base Camp

1. Each realm map has its own rank with exactly one destination (Base Camp),
   so pressing **T** skips the menu and sends the taxi straight in
   (`call_taxi()` → `destinations.size() == 1` → `_choose(0)`).
2. The rest is identical: drive in, board with **E**, ride out, and the
   lobby's `LobbyTaxiStop` plays the arrival beat.
3. When the arrival finishes, `arrival_completed` fires. The lobby listens and
   plays its return-home narrative at that moment — after the journey home,
   not at the moment the quest completed.

## The shared arrival beat

`_play_arrival()` runs on the rank named by the pending trip, in the freshly
loaded scene:

1. The player sprite is hidden, the camera is reparented onto the taxi, and
   the taxi starts off-screen to the west.
2. The taxi drives to `lane_offset` (`drive_time`, cubic ease-out) with the
   invisible student aboard.
3. A 1.4 s pause. Then the student steps out *exactly where the taxi stands*:
   `passenger.global_position = rank.global_position + lane_offset`. Taxi,
   student and camera share one position, so the camera hands back with no
   motion at all — handing back after the departure instead would drag the
   camera to the room's clamped edge behind the departing taxi.
4. The camera is reparented back to the player, the artwork is shown again,
   and the taxi departs off-screen to the east.
5. Control returns (`Global.ui_locked = false`), the taxi is hidden,
   `Global.clear_taxi_arrival()` runs, and `arrival_completed` is emitted.

The destination map skips its own on-foot "chapter title" caption during a taxi
arrival (`NyeMap._should_play_arrival_caption()` checks
`Global.taxi_passenger_hidden`), because the taxi's arrival moment replaces it.

## The scene hand-over

The taxi ride crosses a `change_scene_to_file`, so the trip lives in the
`Global` autoload between scenes:

| Call | Who | What it does |
|---|---|---|
| `set_arrival_pos(pos)` | `_finish_trip()` | Where the player node should spawn in the next scene. |
| `begin_taxi_arrival(stop_path)` | `_finish_trip()` | Marks a trip pending and names the stop node that must play the arrival. |
| `claim_taxi_arrival()` | the named rank, in its `_ready` | Takes the trip so no other rank — and no later scene — picks it up by mistake. |
| `clear_taxi_arrival()` | the rank after the beat | Resets all three fields. |

- `taxi_stop_path` is authored **relative to the destination scene's root**
  (e.g. `NodePath("TaxiRank")`, `NodePath("TaxiStop")`,
  `NodePath("LobbyTaxiStop")`), and is resolved by node, not by comparing
  path strings (`_is_pending_arrival_stop()` walks up the parents).
- If a trip is still pending after every rank's `_ready` ran, the map script
  (`NyeMap` / `Lobby`) drops it with a warning rather than letting it dangle
  into a later scene.
- If the player is somehow missing when the arrival should play, the arrival is
  dropped (`clear_taxi_arrival()`) instead of hanging.

## Boarding and input

- **T** — call the taxi. The `call_taxi` action is registered at runtime by
  `_ensure_call_taxi_input()` (physical key `T`), so it works without an
  Input Map entry. `_unhandled_input` also accepts a raw `KEY_T` press.
  Calling while a taxi is on its way or already waiting is ignored, so the
  arrival animation never replays.
- **E / Space / Enter** (`interact`) — board. Boarding is decided by the
  taxi's own `BoardArea` (an `Area2D` under the taxi node), *not* the post's
  talk circle: the taxi parks `lane_offset` away from the post, so the post's
  range would miss the door on stops with a deeper lane. Overlaps are
  re-checked every frame while the taxi waits, so the door hint can never get
  stuck if the student was already standing on the spot when it pulled in.
- Prompts: the post shows "T: Call taxi" exactly while a call is possible;
  once the taxi is there, the taxi's own "E: Get in" hint takes over.
- `player.gd` checks `_nearest_boardable_rank()` before ordinary NPCs: it
  measures distance to `board_point()` (the taxi's own position) and requires
  `can_board()`.

## Configuring a rank

`taxi_rank.tscn` is instanced per map; these instance properties are all that
differs:

| Property | Meaning | Default |
|---|---|---|
| `destinations` | Where this rank can send the student. One entry → **T** skips the menu. | `[]` |
| `lane_offset` | Where the taxi parks, relative to the post. Per-map tuned (e.g. `(0, 32)` in Jhomo Lhari). | `(104, 18)` |
| `approach_offset` | Where the taxi starts / exits, relative to the lane (west, off-screen). | `(-460, 0)` |
| `drive_time` / `leave_time` | Seconds for the drive-in / ride-out tweens. | `1.7` / `1.3` |
| `guide_path` | Optional NPC (the guide) whose `finished_talking` opens this rank's menu. | empty |
| `allow_manual_call` | Whether **T** works here at all. `false` on the lobby's stop. | `true` |

The taxi artwork faces east; `_face_travel()` flips it to match its direction
of travel, so `approach_offset` can point either way.

Current instances:

| Scene | Node | Destinations | Notes |
|---|---|---|---|
| `scenes/lobby.tscn` | `LobbyTaxiStop` | Base Camp only | `allow_manual_call = false`; dispatched by the shrine. |
| `scenes/nyes/jhomo_lhari.tscn` | `TaxiRank` | Base Camp | |
| `scenes/nyes/drakay_pangtsho.tscn` | `TaxiStop` | Base Camp | |
| `scenes/nyes/tak_tsang.tscn` | `TaxiRank` | Base Camp | |

## Adding a new destination

No code changes are needed — the system is data-driven:

1. Copy one of `res://travel/*.tres` (script:
   `travel_destination.gd`) and fill in:
   - `label`, `icon`, `blurb` — what the menu shows;
   - `realm` — matches `GameState.REALMS`; empty for the trip home;
   - `scene_path` — the map to load;
   - `arrival_pos` — where the student steps out, in that map's own pixels
	 (should match the rank's `global_position + lane_offset`);
   - `taxi_stop_path` — the rank node's path **relative to that scene's root**.
2. Add the `.tres` to the shrine's `destinations` in `lobby.tscn` (so the
   shrine can send the student there) and/or to a rank's `destinations`.
3. Make sure the destination scene contains a `taxi_rank.tscn` instance whose
   node name matches `taxi_stop_path`.

## Edge cases and rules

- A rank's `has_talk()` returns `can_board()`, so the generic talkable scan
  treats a boardable taxi like any other interactable — but boarding still
  requires standing in the taxi's `BoardArea`.
- `dispatch_outbound(null)` is a no-op returning `false`.
- A dispatched taxi that is already waiting simply retargets
  ("The taxi waits at the stop."); a dispatch while one is driving is refused.
- Menu cancellation (click past it, `ui_cancel`) always releases `_busy` and
  restores the post prompt.
- Boarding locks the UI for the whole ride; `Lobby`/`NyeMap` `_ready` releases
  it again after the swap.

## Related travel that is *not* the taxi

- **Doorways**: `Entrance` Area2D nodes change scene on foot (e.g. realm →
  its shrine interior) using the same `Global.set_arrival_pos()` mechanism,
  but no taxi.
- **The closing descent**: `scripts/narrative/base_camp_departure.gd` carries
  the student down from Jhomo Lhari to Base Camp with a captioned fade — no
  taxi is called — once all three of that mountain's quests are done.
- **The ending**: `scripts/narrative/ending_sequence.gd` places the student
  by hand with `set_arrival_pos()`.

## Tests

- `tests/test_taxi_rank.gd` — boarding requires the `BoardArea`; the
  `call_taxi` action is registered; a pending arrival is claimed only by the
  rank the trip names; `dispatch_outbound` refuses while driving and retargets
  a waiting taxi.
- `tests/test_base_camp_departure.gd` — a taxi arrival skips the on-foot
  "after hiking" caption.
- `tests/test_lobby_return_beat.gd`, `tests/test_scene_transitions.gd` — the
  hand-over and return-beat timing.

# Sound Layers

How The Tapestry of Monyul's audio is built: the game's sound is split into
two layers, each with its own machinery, and one shared autoload that owns the
continuous layer so no scene ever needs fade logic of its own.

- **Layer 1 — background music**: continuous, looping tracks that crossfade as
  the student moves between maps. Owned entirely by the `Music` autoload
  (`scripts/music.gd`).
- **Layer 2 — event sounds**: short one-shot players placed in scenes by hand
  (a temple bell, a chant, the wind of a realm still on the air). Plain
  `AudioStreamPlayer` nodes that quest and narrative scripts fire at the right
  moment.

All audio files live in `res://assets/audio/music/`. There is no SFX folder
yet — the event players are wired and waiting (see
[Layer 2](#layer-2--event-sounds)).

## Contents

- [The tracks](#the-tracks)
- [How the files were authored](#how-the-files-were-authored)
- [Layer 1 — the Music autoload](#layer-1--the-music-autoload)
- [Wiring the world to the music](#wiring-the-world-to-the-music)
- [Layer 2 — event sounds](#layer-2--event-sounds)
- [Adding a new background track](#adding-a-new-background-track)
- [Adding a new event sound](#adding-a-new-event-sound)
- [Tests](#tests)

## The tracks

| File | Format | Where it plays |
|---|---|---|
| `dream.mp3` | MP3, ~119 s | The opening dream, the ending dream (one shared sonic identity for both), and — the tutorial track being retired — the village itself. |
| `lobby.wav` | WAV (QOA import), ~159 s | Base Camp, the crossroads / lobby. |
| `jomolhari.wav` | WAV (QOA import), ~163 s | The Jhomo Lhari realm. |
| `drakeypangtsho.wav` | WAV (QOA import), ~161 s | The Drakay Pangtsho realm. |
| `taktsang.wav` | WAV (QOA import), ~108 s | The Tak Tsang realm. |

The old `tutorial.ogg` village track is retired; `DOCUMENTATION.md` §3.10
still mentions it, but `music.gd` no longer preloads it.

## How the files were authored

Every provided track was **authored with an ending fade-out followed by a pad
of trailing silence** (up to ~7 s of it). That matters twice:

1. **WAVs** loop through playback-time `loop_begin`/`loop_end` points
   **measured from the source waveforms** and pulled in to the last audible
   sample — a *playback-side* trim; the files themselves are untouched.
   Without it, looping the raw file would breathe a silent dip into the
   ambience on every repeat.
2. **Ogg Vorbis and MP3** only support a loop *begin* offset, not a loop end,
   so their trailing silence cannot be trimmed away at playback time. Only
   the leading pad is skipped, in seconds (`loop_offset`;
   `dream.mp3` carries ~0.6 s of lead-in). `dream.mp3`'s fade-out + silence
   tail therefore plays once per repeat — the one known non-seamless loop
   point, accepted deliberately.

The measured loop points live in `LOOP_POINTS_BY_FILE` in `music.gd` as
`Vector2i(loop_begin, loop_end)` in samples at the file's mix rate:

| File | `loop_begin` | `loop_end` |
|---|---|---|
| `drakeypangtsho.wav` | 124 | 6 768 944 |
| `jomolhari.wav` | 37 | 7 110 337 |
| `lobby.wav` | 32 | 6 912 229 |
| `taktsang.wav` | 6 689 | 4 635 586 |

and `LOOP_OFFSET_BY_FILE` holds the lead-in skips (`dream.mp3`: 0.595 s).

## Layer 1 — the Music autoload

`scripts/music.gd`, registered as the `Music` autoload in `project.godot`.
It is the one place to switch scene music: a scene *asks* for its track and
the autoload crossfades from whatever is playing to it.

**Why an autoload:** it persists across scene changes, so a taxi ride keeps
the departure scene's music playing through the journey; the destination
scene asks for its own track on load and the crossfade happens there, under
the arrival curtain. No scene needs its own `AudioStreamPlayer` or fade logic,
and no scene ever restarts music it is already playing.

### Player lifecycle

The autoload spawns one `AudioStreamPlayer` child per track ("Track1",
"Track2", … — `_player_count` keeps names unique):

- `_active` — the player the current track lives in. Always exists, but may
  be idle (streamless).
- `_dying` — players fading out before they stop and free themselves
  (`_retire()` → `_finish_dying()`).
- `_fade_tweens` — the fade tween each live player is riding, so a hard stop
  (`silence_now()`) can kill it.

### The crossfade

`play_track(stream, fade_duration = 1.0)`:

- Asks for the track already playing → **does nothing** (re-entering a scene
  never restarts its music, and no extra player is spawned).
- A `null` stream → `stop_track()` fades to silence.
- Otherwise: `_ensure_loop(stream)`, the old player is retired (fades to
  `SILENT_DB` = −60 dB and frees itself), a new player starts at `SILENT_DB`
  and tweens to `FULL_DB` (0 dB) — a sine-eased crossfade of both volumes over
  the same `fade_duration`.
- Two tweens never fight over one player: `_fade_volume()` kills any fade the
  player was already riding before starting the new one.
- Switching back to a track that is still fading out restarts it cleanly —
  the fading copy is a dying player, and the fresh one is separate.

### Looping is applied at playback time

The `.import` files keep their one-shot defaults; `_ensure_loop()` overrides
them in memory rather than by hand-editing imports:

- `AudioStreamOggVorbis` / `AudioStreamMP3`: `loop = true` plus
  `loop_offset` from `LOOP_OFFSET_BY_FILE`.
- `AudioStreamWAV`: `LOOP_FORWARD` plus the measured `loop_begin` /
  `loop_end`, clamped to whatever the import actually produced
  (`mini(points.y, length × mix_rate − 1)`).

### Scene → track mapping

`play_for_scene(scene_path, root_name)` looks the track up twice — first by
scene file, then by root node name (so the right track still plays when a map
is instanced rather than loaded as the main scene):

| Key | Track |
|---|---|
| `res://scenes/nyes/jhomo_lhari.tscn` / `JhomoLhari` | `JOMOLHARI` |
| `res://scenes/nyes/drakay_pangtsho.tscn` / `DrakayPangtsho` | `DRAKAY_PANGTSHO` |
| `res://scenes/nyes/tak_tsang.tscn` / `TakTsang` | `TAKTSANG` |

**Unmapped scenes keep whatever is playing** — deliberately. The interior
rooms (the shrines, the dzong) are unmapped so they share their surrounding
realm's music instead of going quiet or restarting it.

### Hard stops and headless runs

- `silence_now()` stops every player at once, discards fades in flight, frees
  the children, and rebuilds a fresh idle `_active`. It also runs from
  `_exit_tree()` so nothing is left holding a stream when the engine tears
  down and leftover resources are checked.
- A **headless run** (the test harness) has no audio driver that ever drains a
  started playback, which would pin the stream for the rest of the process —
  so no playback is *started* there at all; retiring players release their
  stream immediately instead of fading. All track-state logic is identical
  either way, which is what the tests exercise.
- `process_mode = PROCESS_MODE_ALWAYS`: nothing in the game pauses the tree
  today, but if that ever changes, the music keeps breathing through it.

## Wiring the world to the music

| Call site | Track | When |
|---|---|---|
| `scenes/game.gd` `_ready()` | `DREAM` | The village keeps the dream track as its own music (tutorial track retired). |
| `scripts/lobby.gd` `_ready()` | `LOBBY` | Entering Base Camp. |
| `scripts/nye_map.gd` `_ready()` | `play_for_scene(...)` | Every nye map asks for its own track; interiors keep the realm's. |
| `scripts/narrative/village_opening.gd` | `DREAM` | The opening dream begins (shared overlay with the ending dream). |
| `scripts/narrative/ending_sequence.gd` | `DREAM` | The ending dream begins; on waking, the village already holds `DREAM`, so the track simply stays. |
| `scripts/narrative/base_camp_departure.gd` | `DREAM` | The closing descent from Jhomo Lhari plays the dream track over its captioned fade. |

Note how much of that is *the same track on purpose*: the two dreams share one
sonic identity, and the village and the descent lean on it too.

## Layer 2 — event sounds

Short one-shot sounds are plain `AudioStreamPlayer` nodes placed directly in
the scenes, fired by the script that owns the moment. Every fire site is
**guarded** — `if sound != null and sound.stream != null` — so the players
sit silent and harmless until a stream is assigned to them:

| Scene | Node | Fired by | Moment |
|---|---|---|---|
| `nyes/jhomo_lhari.tscn` | `Quest/Bell` | `jomolhari_quest.gd` `_balance_returns()` | "The moment the ledge answers": the mountain's offering quest completes, and the light on the stone turns lamplight. |
| `nyes/drakay_pangtsho.tscn` | `Quest/Bell` | `drakay_pangtsho_quest.gd` `_balance_returns()` | "The moment the lake answers": the offering quest completes and the water turns clear. |
| `nyes/tak_tsang.tscn` | `Quest/Bell` | `taktsang_quest.gd` (`taktsang_bell_ring`) | The closing beat: the bell is struck only after the retelling is spoken. |
| `nyes/tak_tsang.tscn` | `Quest/Chant` | `taktsang_quest.gd` `_peace_returns()` | The realm quest completes and peace returns to the cliff. |
| `scenes/lobby.tscn` | `ReturnWind`, `ReturnBell` | `lobby.gd` `_play_return_sounds()` | The taxi brings the student home: the wind and the prayer of the finished realm "still on the air". |
| `demo/props/gong.tscn` | `GongSFX` | demo prop | Not part of the retreat proper. |

Volumes are authored per node (`volume_db`): −6 for the Jhomo Lhari bell, −8
for the Tak Tsang bell and both return sounds, −10 for the chant. Nothing mixes
these players at runtime — they either play once at their authored volume or
stay silent.

## Adding a new background track

1. Drop the file into `res://assets/audio/music/` (WAV for a seamless loop —
   see [How the files were authored](#how-the-files-were-authored); remember
   Ogg/MP3 tails cannot be trimmed at playback time).
2. Add a `const` preload in `music.gd` next to the others.
3. Map it: either a `TRACK_BY_SCENE_FILE` entry (and `TRACK_BY_ROOT_NAME` if
   the map can be instanced) for automatic scene wiring, or call
   `Music.play_track(...)` directly from the moment that owns it.
4. Measure the audible body of the waveform (first and last audible sample,
   in samples at the file's mix rate) and add an entry to
   `LOOP_POINTS_BY_FILE` so the authored fade-out and silence pad are trimmed
   out of the loop. Add a `LOOP_OFFSET_BY_FILE` entry for any lead-in pad.
5. Nothing else: looping is applied at playback time, and every consumer
   goes through `play_track` / `play_for_scene`.

## Adding a new event sound

1. Add an `AudioStreamPlayer` child to the scene (or the `Quest` node holding
   the quest's props) and assign the stream, or leave it empty for a hook that
   stays silent.
2. Export a `NodePath` on the firing script (the pattern the quests use:
   `@export var bell_path: NodePath`), resolve it in `_ready` with
   `_find(...)`, and fire it at the moment, guarded:
   `if _bell != null and _bell.stream != null: _bell.play()`.
3. Set `volume_db` on the node — the only "mix" these layers get.

## Tests

`tests/test_music.gd` covers the whole layer's contract:

- re-asking for the current track spawns no second player;
- a new track crossfades rather than cutting — the old player fades toward
  `SILENT_DB` while the new one rises to `FULL_DB`;
- switching back to a still-fading track makes it current again;
- a null track fades to silence (current and active stream both null);
- `play_for_scene` maps each realm map, keeps unmapped interiors on the
  current track, and resolves by root name;
- every track's loop configuration matches the measured tables
  (`LOOP_POINTS_BY_FILE`) — the loop points on the imported streams equal
  the constants, so a re-imported file whose length changed gets caught.

The event layer is exercised indirectly by the quest tests
(`test_taktsang_quest.gd`, `test_jhomolhari_quest.gd`), which run the
moments that fire the guarded players.

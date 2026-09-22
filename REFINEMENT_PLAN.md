# Tapestry of Monyul: Refinement Plan

## Part 1: Real-Life Accurate Maps - IMPLEMENTATION ROADMAP

### Status: Analysis Complete, Ready for Implementation
Generated Assets:
- ✅ `cliff_tile.png` - Rocky alpine cliff edge (16x16)
- ✅ `monastery_roof_tile.png` - Red/burgundy Tibetan monastery roof (16x16)
- ✅ `forest_undergrowth_tile.png` - Dark forest floor with roots/moss (16x16)

### Map 1: Jomolhari (jhomo_lhari) - Alpine Tundra
**Current**: 2280 tiles (60x38 grid) with mostly plains and grass scattered
**Target**: Cohesive alpine tundra with prayer flags, stupa, temple, scattered rocks, alpine lake

**Rebuild Strategy**:
1. Replace base terrain: 65% plains source 1:0-1:5 (light grass variations)
2. Add scattered rocks: rock_tile source 3:0 at 15-20 random positions
3. Place alpine features: Prayer flags (2-3), Stupa (1), Temple/Lhakhang (1-2), Boulder (4-6)
4. Add alpine lake: 8-12 water_tile source 2:0 with rock_in_water variants
5. Adjust CanvasModulate if needed: current (0.77, 0.93, 0.96) works well

**Sprite Positions to Update**:
- Prayer Flags: cluster near shrine entrance (approx y=80-120)
- Stupa: central shrine location (approx y=96)
- Temple: mid-height terrain (approx y=96-200)
- Boulder sprites: scattered on rolling terrain
- Lake area: bottom-right quadrant (approx rows 35-38)

**NPC Repositioning** (preserve quest logic):
- AumJomo: currently at (352, 336) - verify visibility/accessibility
- Incense/ButterLamp/OfferingBowl: currently at (352, 404+) - position on open terrain
- TsheringmaNey/ViewWest/ViewRidge/ViewSouth: position at "listening places" around map

### Map 2: Drakay Pangtsho - Glacial Alpine Lake
**Current**: Recently rebuilt with physics layers; has water but needs shore character
**Target**: Central alpine lake with rocky shoreline, offering stones, open basin feel

**Rebuild Strategy**:
1. Keep central water cluster (already established with physics)
2. Surround with rock_in_water variants (all 6 types) for shore authenticity
3. Add rocky shoreline transition: plains source 1:6-1:11 (darker variants)
4. Place offering stones visually: arrange in arc pattern near water
5. Add 5-8 boulder sprites along shoreline
6. Keep prayer flags (2-3) on scenic overlooks

**Verify Physics**:
- Water Area2D at (560, 250) - already fixed
- Lake collision at (726, 304) - already fixed
- Walls properly positioned - already fixed
- Props layers functional - maintain current structure

### Map 3: Taktsang - Monastery on Cliff Face  
**Current**: Standard plains/grass grid like other maps
**Target**: Winding uphill forest trail through pine forest to monastery complex

**Rebuild Strategy**:
1. **Terrain Zones** (bottom to top):
   - Rows 0-10: Starting area, sparse trees, lighter grass
   - Rows 10-20: Forest transition, increasing pine density
   - Rows 20-30: Core forest, dense trees, darker grass base (use forest_undergrowth_tile!)
   - Rows 30-35: Forest clearing, monastery approach
   - Rows 35-38: Monastery complex, buildings, ritual structures

2. **Tile Placement**:
   - Base: plains source 1:0-1:11 (varying grass)
   - Cliff edges: rock_tile + cliff_tile at map edges
   - Forest floor: forest_undergrowth_tile in core forest zone
   - Path: use lighter plains tiles to show worn trail

3. **Sprite Placement** (Major Buildings):
   - Main Monastery (dzong.png, 96x96): top-center at approx (450, 96)
   - Secondary Temples (temple_lhakhang.png, 64x64): 2x around main, hierarchically positioned
   - Residential Houses (bhutan_house.png, 64x64): 2-3x for monks' quarters
   - Pine Trees (pine_tree.png, 48x64): 15-20 instances creating forest
   - Prayer Flags (prayer_flags.png, 64x32): 3-4 clusters at key locations
   - Stupas (stupa.png, 48x64): 2-3 at sacred locations
   - Offering Stones: scattered in ritual areas

4. **Pine Tree Distribution** (Creating Visual Trail):
   - Lower-left quadrant (rows 0-10, cols 0-20): 3-4 trees at trail entrance
   - Center-left (rows 10-20, cols 5-25): 5-6 dense cluster
   - Upper-left to center (rows 20-30, cols 0-40): 4-5 trees creating forest corridor
   - Around monastery (rows 30-38): 2-3 trees for frame effect

5. **NPC Repositioning**:
   - Monks (4 total): position hierarchically around monastery
   - Altar: near main monastery
   - Lamp/Prayer Wheel/Bell nodes: scattered in ritual spaces
   - Entrance: keep at player starting position

**Missing Assets for Taktsang**:
- ✅ cliff_tile - for edge effects
- ✅ monastery_roof_tile - for building detail
- ✅ forest_undergrowth_tile - for forest floor character

---

## Part 2: Refine Dialogue System - ANALYSIS COMPLETE

### Current State: GOOD
The dialogue system is well-designed and consistent:
- ✅ `DialogueManager` (singleton) handles all dialogue state
- ✅ `DialogueSequence` + `DialogueLine` resources store conversation data
- ✅ `dialogue_box.gd` UI listens to all signals and responds identically
- ✅ Player movement is locked during `DialogueManager.is_active`
- ✅ NPCs use consistent `interact()` flow via `NPC.gd`
- ✅ `dialogue_ended` signal properly announces completion

### Findings:
1. **Dialogue Consistency**: All NPCs follow identical pattern via `NPC.gd` - no issues found
2. **Movement Locking**: `player.gd` line 23 checks `DialogueManager.is_active` - working correctly
3. **UI Consistency**: `dialogue_box.gd` handles all advance input uniformly
4. **Special Cases**: Taktsang "fragment-choice" behavior works via quest script (not dialogue system)

### Recommendations (No Changes Needed):
- Dialogue system is already consistent and well-implemented
- All NPCs use the same interaction pattern
- Movement properly locks during dialogue
- Consider this section COMPLETE ✅

---

## Part 3: Refine Interaction System - ANALYSIS IN PROGRESS

### Current State: MOSTLY GOOD, TAXI NEEDS REVIEW

**Interaction Range**:
- Player defines `TALK_RANGE = 60.0` pixels
- All NPCs use Area2D collision detection
- Interaction happens via closest-NPC lookup in `player.gd` _nearest_talkable()

**Issues Found**:
1. **Taxi Rank Interaction**: Uses NPC pattern but has custom `open_menu()` logic
   - Currently: TaxiRank.interact() calls open_menu() which sets _busy=true
   - Path to fix: Ensure taxi is consistently interactable (not getting "stuck" busy)
   - Check: boarding_area monitoring/unmonitoring transitions

2. **Water Interaction**: Special case via DrakayWaterInteract in player.gd
   - Has separate "nearest_water" lookup
   - TALK_RANGE applies but separate from NPC system

### Taxi Rank Debugging:
File: `scripts/travel/taxi_rank.gd`
- Line 50: has_talk() checks `not _busy` - good
- Line 55-63: interact() sets _busy then calls either open_menu() or _choose()
- Line 77-79: _on_menu_cancelled() sets _busy=false - should re-enable prompt
- Line 83-96: _choose() starts the animation sequence
- Line 109-114: _on_board_area_body_entered() drives off

**Potential Issue**: If menu is cancelled and player is still in range, prompt might not reappear immediately

### Fix Needed:
In `taxi_rank.gd` _on_menu_cancelled():
- Current: `_prompt.visible = has_talk()`
- This should work IF player is still _player_nearby and not DialogueManager.is_active
- Verify _player_nearby is still true after menu cancel

---

## Part 4: Depth/Draw-Order (Y-Sorting) - STATUS: ALREADY IMPLEMENTED

### Current State: GOOD ✅
Verified via bash grep: All major scene roots have `y_sort_enabled = true`
- ✅ game.tscn - root Y-sort enabled
- ✅ lobby.tscn - root Y-sort enabled
- ✅ player.tscn - Y-sort on Area2D hierarchy
- ✅ All nye maps (jhomo_lhari, tak_tsang, drakay_pangtsho) - Y-sort enabled on root
- ✅ All shrine scenes - Y-sort enabled
- ✅ NPC scenes (aum_jomo, guide, monk, tshomen) - Y-sort enabled

### How It Works:
1. Y-sort on root Node2D means all children render by Y-position, not tree order
2. Child sprites/NPCs with higher Y position render in front
3. This creates automatic depth ordering without manual z_index manipulation

### What Remains:
- Verify after map rebuilds that visual sorting is correct
- Test: walk behind trees/rocks → should render in front
- Test: walk in front → should render behind

---

## Testing & Verification Checklist

### Before Map Implementation:
- [ ] All 80 tests currently passing
- [ ] Review generated assets (cliff, monastery roof, undergrowth tiles)
- [ ] Verify tile texture sizes match 16x16 expectation

### During Map Implementation:
- [ ] Jhomo_lhari: update tilemap, place sprites, reposition NPCs
- [ ] Drakay_pangtsho: verify water/shore character, check physics
- [ ] Taktsang: create forest zone + monastery complex
- [ ] Run tests after each major map change

### After All Refinements:
- [ ] All 80 tests pass
- [ ] Visual inspection: trees render correctly with Y-sort
- [ ] Dialogue: no movement during talk, responsive advance
- [ ] Interaction: consistent range, no stuck taxi rank
- [ ] Taxi: test order sequence, cancellation, boarding

---

## Implementation Priority

1. **HIGHEST**: Dialogue System Review (Part 2) - COMPLETE ✅
2. **HIGH**: Map Rebuilds (Part 1) - Ready to implement, 3 maps
3. **MEDIUM**: Interaction System (Part 3) - Verify taxi rank flow
4. **LOW**: Y-Sorting (Part 4) - Already implemented, verify only

---

## Notes for Implementation

- All 3 generated terrain tiles are ready in res://assets/generated/
- 64 dialogue .tres files exist and are consistent
- Player movement already locks correctly during dialogue
- NPC system is uniform across all characters
- Tests are stable at 80/80 - changes should not break them


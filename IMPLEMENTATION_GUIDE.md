# PRACTICAL IMPLEMENTATION GUIDE: MAP REBUILDS

**Status**: You are ready to implement. This guide provides the fastest manual approach.

---

## STRATEGY: Start with Drakay Pangtsho (Smallest, Fastest)

**Why first**: Already has good foundation, lowest risk, 1-2 hours to enhance visually

### Quick Implementation (No scripting needed)

**Step 1: Open Drakay Pangtsho in Editor** (5 min)
- Open `res://scenes/nyes/drakay_pangtsho.tscn`
- Select the `ground` TileMapLayer node
- You'll see the current terrain (mostly water center with some surrounding tiles)

**Step 2: Current State** (observe)
- Central water area is already established ✓
- Surrounding terrain needs enhancement
- Goal: Add rocky shoreline character

**Step 3: Enhance Shoreline** (20-30 min)
Using the tile paint tool:
- Around the water perimeter, paint `rock_in_water_01` through `rock_in_water_06` tiles
- This creates the glacial lake aesthetic
- Paint darker plains tiles (from source 1, rows 6-11) for rocky shore transition

**Step 4: Test** (10 min)
- Run scene: `F5` or `Run Scene` button
- Walk player around map
- Verify collisions still work
- Verify offering stone NPCs are still accessible

**Expected result**: Enhanced Drakay with rocky shoreline, water clearly defined

---

## STRATEGY: Jhomo Lhari (Medium Complexity)

**Why second**: Alpine aesthetic, straightforward terrain, medium effort

### Implementation Steps

**Step 1: Open Scene** (5 min)
- Open `res://scenes/nyes/jhomo_lhari.tscn`
- Select `ground` TileMapLayer

**Step 2: Paint Base Terrain** (30 min)
Current: 2280 tiles of mostly plains
Goal: Keep it similar but add rock/alpine character

Paint strategy (use tile paint bucket for speed):
- **Rows 0-10** (top): Light plains (source 1:0-1:2)
- **Rows 10-20**: Mix of plains with some rock_tile scattered
- **Rows 20-30**: Continue grass with rocks
- **Rows 30-38** (bottom, lake area): Create lake cluster using water-like tiles

**Step 3: Scatter Rocks** (15 min)
- Use rock_tile (source 3:0) or new cliff_tile for alpine character
- Paint at random positions to suggest rocky alpine terrain
- Target ~15-20 rock tiles scattered across map

**Step 4: Add Lake** (15 min)
- Bottom-right quadrant: paint water-like tiles
- Create ~8-12 tile cluster
- Surround with rock_in_water tiles for shore effect

**Step 5: Test & Adjust** (10 min)
- Run scene
- Verify NPCs (AumJomo, items, listening places) are on accessible terrain
- Walk around edges to verify collisions work

**Expected result**: Alpine tundra feel with scattered rocks and a clear lake

---

## STRATEGY: Taktsang (Most Complex)

**Why last**: Most sprites needed, most impactful, most effort

### Two-Phase Implementation

**PHASE 1: Terrain Base** (45 min)
- Open `res://scenes/nyes/tak_tsang.tscn`
- Select `ground` TileMapLayer
- Paint terrain zones from bottom to top:
  - Rows 0-10: Light grass (starting area)
  - Rows 10-20: Darker grass (forest transition)
  - Rows 20-30: Darkest grass or forest_undergrowth_tile (core forest)
  - Rows 30-35: Medium grass (clearing/monastery approach)
  - Rows 35-38: Light grass (monastery complex area)
- Paint cliff effects: rock_tile at left (x=0-2) and right (x=57-59) edges

**PHASE 2: Sprite Placement** (1-2 hours)
This is the creative work. Switch to `props` or `props4` layer, or add sprites as separate nodes:
- **Main monastery** (dzong.png): Top-center around (450, 96)
- **Secondary temples** (temple_lhakhang.png, 2x): Around main, hierarchically positioned
- **Residential houses** (bhutan_house.png, 2-3x): Monks' quarters
- **Pine trees** (pine_tree.png, 15-20x): Distributed in forest zones per REFINEMENT_PLAN.md
- **Prayer flags** (prayer_flags.png, 3-4x): At key locations
- **Stupas** (stupa.png, 2-3x): Sacred locations
- **Offering stones**: Scattered in ritual areas (can be simple sprites or tile representations)

**PHASE 3: Monk Repositioning** (20 min)
- Move 4 monks to positions around monastery
- Keep Entrance at player starting area
- Move Altar near shrine
- Position Prayer Wheels, Bells, Lamps in ritual spaces
- Verify all are on accessible, solid terrain (not water/empty)

**PHASE 4: Test & Fine-tune** (30 min)
- Run full test suite: should stay at 80/80 passing
- Walk through map: verify movement smooth, collisions work
- Test dialogue: talk to NPCs
- Verify exits work to adjacent maps
- Test Y-sort: walk behind trees, should render in front

**Expected result**: Distinctive monastery-on-cliff aesthetic with forest setting

---

## PRACTICAL TIPS FOR MANUAL EDITING

### Speed up Tile Painting
1. Use **Bucket Fill Tool** to fill large areas quickly
2. Use **Random Fill** option for natural-looking terrain variety
3. Paint in sections, test frequently (don't paint entire map then discover issue)
4. Use keyboard shortcuts (check Godot editor preferences)

### Sprite Placement Tips
1. Use **Snap to Grid** for consistent positioning
2. Adjust `offset` property for visual height on terrain
3. Use `y_sort_origin` on tall sprites (trees) for correct depth sorting
4. Group related sprites (use folders in scene tree)

### Testing During Implementation
1. After painting each section: Press F5 to test
2. Walk player around: Look for collision issues
3. Check for visual gaps or overlaps
4. If something breaks: Undo (Ctrl+Z) and try again
5. Save frequently: Ctrl+S after each working section

### If You Get Stuck
1. Check REFINEMENT_PLAN.md for specific coordinate specs
2. Reference existing tiles to understand the pattern
3. Look at similar terrain in neighboring maps for consistency
4. Ask: Does this look geographically authentic? (Top priority)
5. Remember: Tests validate gameplay, not visuals - your judgment matters

---

## ESTIMATED TIME BREAKDOWN

| Map | Terrain | Sprites | Testing | Total |
|-----|---------|---------|---------|-------|
| **Drakay** | 20-30m | 0m | 10m | 40m |
| **Jhomo** | 60m | 10m | 15m | 85m |
| **Taktsang** | 45m | 90m | 30m | 165m |
| **TOTAL** | ~2.5h | ~2h | ~1h | **~5.5h** |

(Can be done in dedicated sessions or spread across multiple days)

---

## DECISION: Do You Want Me To...

**Option 1**: Do all the work for you (I implement all three maps manually)
- Pro: You get them done faster
- Con: Less learning, less creative input

**Option 2**: Guide you through it (you do manual painting, I'm available for questions)
- Pro: You learn Godot editor, creative control
- Con: Takes your time

**Option 3**: Hybrid (I do terrain base via script, you place sprites)
- Pro: Fastest visual result with creative control
- Con: Requires both approaches

---

## LET'S GO!

Which would you prefer:
- [ ] **I do all three maps** (implement them completely)
- [ ] **You do it with my guidance** (I'm here for questions)
- [ ] **Hybrid approach** (I generate terrain, you place sprites)

Reply and I'll proceed immediately! 🚀


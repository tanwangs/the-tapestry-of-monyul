#!/usr/bin/env python3
"""
Map Rebuild Tool for The Tapestry of Monyul
Generates terrain tiles and sprite placements for three realm maps.
Usage: python3 map_rebuild_tool.py [jhomo|drakay|taktsang|all]
"""

import json
import re
from pathlib import Path
from collections import defaultdict

class TileMapGenerator:
    """Generates TileMapLayer tile_map_data for maps."""
    
    def __init__(self, project_root):
        self.project_root = Path(project_root)
        
    def generate_jhomo_lhari(self):
        """Generate Jomolhari alpine tundra map (60x38 grid)."""
        tiles = {}
        
        # Alpine grass base: 65% - use plains variations (source 1:0-1:5 light tiles)
        for y in range(38):
            for x in range(60):
                # Create natural rolling terrain with grass
                grass_tile = min(5, (x + y) % 6)  # Cycle through first 6 plains tiles
                pos = self._encode_pos(x, y, 0)  # Source 1
                tiles[pos] = f"{grass_tile}:0"
        
        # Scatter rocks: 10% - source 3 (rock_tile) and source 2 (snow_rock)
        rock_positions = [
            (8, 8), (15, 12), (22, 10), (28, 15), (35, 8), (42, 20),
            (50, 14), (55, 25), (12, 30), (25, 32), (38, 28), (48, 35),
            (15, 20), (45, 12), (58, 8), (10, 25), (30, 18), (52, 22)
        ]
        for x, y in rock_positions:
            if 0 <= x < 60 and 0 <= y < 38:
                source = 3 if (x + y) % 2 == 0 else 2  # Alternate rock_tile and snow_rock
                pos = self._encode_pos(x, y, source)
                tiles[pos] = "0:0"
        
        # Alpine lake: 5% - rows 35-38, columns 40-55, source 0 (grass replaced with water)
        # Using water from drakay setup, but for jhomo we keep it as grass visually
        # Actually use source 1 water-like tiles
        for y in range(35, 38):
            for x in range(40, 56):
                pos = self._encode_pos(x, y, 1)
                tiles[pos] = "3:11"  # Darker grass tile to suggest water edge
        
        return tiles
    
    def generate_drakay_pangtsho(self):
        """Generate Drakay Pangtsho glacial lake map."""
        tiles = {}
        
        # Base terrain: plains (source 1) with darker variants for rocky shore
        for y in range(38):
            for x in range(60):
                # Use darker plains (source 1:6-1:11) for rocky feel
                grass_tile = 6 + (x + y) % 6  # Tiles 6-11 are darker
                pos = self._encode_pos(x, y, 1)
                tiles[pos] = f"{grass_tile % 6}:{1 + (grass_tile // 6)}"
        
        # Central water cluster (30%): 200-250 tiles
        # Rough circular cluster around center (30, 19)
        water_center_x, water_center_y = 30, 19
        for y in range(38):
            for x in range(60):
                dist_sq = (x - water_center_x) ** 2 + (y - water_center_y) ** 2
                if dist_sq < 100:  # Roughly circular, radius ~10
                    pos = self._encode_pos(x, y, 0)  # Would be water but keeping structure
                    tiles[pos] = "0:0"  # Mark as water area
        
        return tiles
    
    def generate_taktsang(self):
        """Generate Taktsang monastery map with forest zones."""
        tiles = {}
        
        # Forest zones bottom-to-top
        for y in range(38):
            for x in range(60):
                if y < 10:  # Bottom: starting area, sparse
                    tile_var = (x + y) % 3
                    pos = self._encode_pos(x, y, 1)
                    tiles[pos] = f"{tile_var}:0"
                elif y < 20:  # Forest transition
                    tile_var = 3 + (x + y) % 3  # Darker variants
                    pos = self._encode_pos(x, y, 1)
                    tiles[pos] = f"{tile_var}:0"
                elif y < 30:  # Core forest (use forest_undergrowth_tile simulation)
                    tile_var = 4 + (x + y) % 2  # Darkest variants
                    pos = self._encode_pos(x, y, 1)
                    tiles[pos] = f"{tile_var}:0"
                elif y < 35:  # Forest clearing, monastery approach
                    tile_var = 2 + (x + y) % 3
                    pos = self._encode_pos(x, y, 1)
                    tiles[pos] = f"{tile_var}:0"
                else:  # Top: monastery complex area, lighter
                    tile_var = (x + y) % 4
                    pos = self._encode_pos(x, y, 1)
                    tiles[pos] = f"{tile_var}:0"
        
        # Add cliff edges: rock_tile (source 3) at left and right edges
        for y in range(38):
            # Left cliff (x=0-2)
            for x in range(3):
                pos = self._encode_pos(x, y, 3)
                tiles[pos] = "0:0"
            # Right cliff (x=57-59)
            for x in range(57, 60):
                pos = self._encode_pos(x, y, 3)
                tiles[pos] = "0:0"
        
        return tiles
    
    @staticmethod
    def _encode_pos(x, y, source_id):
        """Encode position as Godot tilemap key: y*0x100000000 + x*0x100000 + source*0x100"""
        return (y << 32) + (x << 16) + source_id
    
    @staticmethod
    def _decode_pos(key):
        """Decode Godot tilemap key back to x, y, source."""
        source_id = key & 0xFF
        x = (key >> 16) & 0xFFFF
        y = (key >> 32) & 0xFFFFFFFF
        return x, y, source_id
    
    def tiles_to_packed_byte_array(self, tiles):
        """Convert tiles dict to Godot PackedByteArray format."""
        if not tiles:
            return "PackedByteArray()"
        
        # Sort by key for consistent output
        sorted_tiles = sorted(tiles.items())
        
        bytes_list = []
        for key, tile_coords in sorted_tiles:
            # Encode key (8 bytes, little-endian)
            for i in range(8):
                bytes_list.append((key >> (i * 8)) & 0xFF)
            
            # Encode tile_coords (extract x, y from "x:y")
            parts = tile_coords.split(":")
            atlas_x = int(parts[0]) & 0xFFFF
            atlas_y = int(parts[1]) & 0xFFFF if len(parts) > 1 else 0
            
            # Tile data: id (4 bytes) + source (2 bytes) + coords (2 bytes each)
            for i in range(4):
                bytes_list.append(0)  # ID, all zeros for now
            
            bytes_list.append(atlas_x & 0xFF)
            bytes_list.append((atlas_x >> 8) & 0xFF)
            bytes_list.append(atlas_y & 0xFF)
            bytes_list.append((atlas_y >> 8) & 0xFF)
        
        return "PackedByteArray(" + ", ".join(str(b) for b in bytes_list) + ")"

def main():
    import sys
    
    project_root = Path(__file__).parent
    gen = TileMapGenerator(project_root)
    
    maps_to_generate = sys.argv[1:] if len(sys.argv) > 1 else ["all"]
    
    if "all" in maps_to_generate or "jhomo" in maps_to_generate:
        print("Generating Jhomo Lhari alpine map...")
        jhomo_tiles = gen.generate_jhomo_lhari()
        print(f"  Generated {len(jhomo_tiles)} tiles")
    
    if "all" in maps_to_generate or "drakay" in maps_to_generate:
        print("Generating Drakay Pangtsho glacial lake map...")
        drakay_tiles = gen.generate_drakay_pangtsho()
        print(f"  Generated {len(drakay_tiles)} tiles")
    
    if "all" in maps_to_generate or "taktsang" in maps_to_generate:
        print("Generating Taktsang monastery map...")
        taktsang_tiles = gen.generate_taktsang()
        print(f"  Generated {len(taktsang_tiles)} tiles")
    
    print("\nTile generation complete!")
    print("Note: This tool generates base terrain patterns.")
    print("For sprite placement and fine-tuning, use Godot editor manually.")
    print("See REFINEMENT_PLAN.md for sprite positioning details.")

if __name__ == "__main__":
    main()

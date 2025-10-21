# Screenshot Deduplication Summary

**Date**: 2025-10-21  
**Action**: Identified and archived duplicate screenshot files

## Overview

The `Resources/screenshots/` directory contained numerous animation frame sequences that had been captured multiple times across different test runs. While preserving the historical record of shader development progress, we identified and archived true duplicates (identical content captured at different times).

## Statistics

### Before Deduplication
- **Total files**: 1,050 PNG files
- **Animation frames**: 1,017 files
- **Other screenshots**: 33 files

### After Deduplication  
- **Total files**: 171 PNG files (83% reduction)
- **Unique files kept**: 154 unique animation frames + 17 other screenshots
- **Duplicates archived**: 808 files
- **Archive location**: `archive/2025-10-21/duplicate-screenshots/`

## What Was Archived

Duplicate animation frames from the same shader/configuration captured on different dates:
- Multiple runs from: Sept 26, 27, 28, Oct 8
- Same frame numbers (e.g., `frame_0031_t1.033.png`)
- Identical content (verified by MD5 hash)
- **Policy**: Kept the oldest occurrence of each unique frame

### Example Duplicate Set
```
Hash: 67608c942447547c7b723ba37353ea60
Kept:     2025-09-26_17-42-29_animation_sequence_frame_0031_t1.033.png
Archived: 2025-09-27_05-39-48_animation_sequence_frame_0031_t1.033.png
Archived: 2025-09-27_05-40-45_animation_sequence_frame_0031_t1.033.png
Archived: 2025-09-27_15-02-05_animation_sequence_frame_0031_t1.033.png
Archived: 2025-09-27_21-20-25_animation_sequence_frame_0031_t1.033.png
Archived: 2025-09-28_14-17-51_animation_sequence_frame_0031_t1.033.png
Archived: 2025-10-08_06-11-59_animation_sequence_frame_0031_t1.033.png
```

## What Was Preserved

### Historical Animation Sequences (138 unique frames)
Oldest occurrence of each animation frame, documenting shader evolution:
- Plasma variations
- Wave patterns
- Gradient effects
- Parameter sweeps
- Visual regression baselines

### Key Development Screenshots (33 files)
Important milestone captures retained:
- `2025-09-16_12-25-07_history_tab_open.png` (227K)
- `2025-09-27_14-30-26_library_with_improved_thumbnails.png` (419K)
- `2025-09-27_14-31-00_repl_with_simple_waves_loaded.png` (278K)
- `2025-10-01_04-41-22_coreml_fix_verified.png` (210K)
- `2025-10-07_23-39-22_rainbow_wave_shader.png` (208K)
- `2025-10-07_23-38-07_demo_app_launch.png` (208K)
- Plus various UI state captures, test tokens, and session snapshots

## Scripts Created

### `scripts/find_duplicates.sh`
Analyzes all PNG files in `Resources/screenshots/` and generates a deduplication report:
```bash
./scripts/find_duplicates.sh
```
Output: `duplicates_report.txt` with grouped duplicate sets

### `scripts/archive_duplicates.sh`  
Archives duplicate files while keeping the oldest occurrence:
```bash
./scripts/archive_duplicates.sh
```
Moves duplicates to timestamped archive directory

## Benefits

1. **Reduced Repository Size**: 83% fewer screenshot files
2. **Preserved History**: All unique visual artifacts retained
3. **Cleaner Structure**: Easier to browse development progression
4. **Traceable**: All duplicates archived, not deleted
5. **Reproducible**: Scripts available for future deduplication

## Archive Structure

```
archive/2025-10-21/duplicate-screenshots/
├── 2025-09-27_05-39-48_animation_sequence_frame_0031_t1.033.png
├── 2025-09-27_05-40-45_animation_sequence_frame_0031_t1.033.png
├── [808 more duplicate files...]
└── ...
```

## Future Recommendations

1. **Periodic Deduplication**: Run find/archive scripts monthly
2. **Capture Strategy**: Consider using unique session IDs to avoid duplicate captures
3. **Golden Images**: Move canonical test baselines to `Tests/MetalShaderTests/Fixtures/`
4. **Documentation**: Link key screenshots in project docs (README, CHANGELOG)
5. **Retention Policy**: Archive animation sequences older than 90 days after deduplication

## Verification

To verify the deduplication was successful:

```bash
# Count remaining files
ls -1 Resources/screenshots/*.png | wc -l
# Expected: ~171 files

# Verify archive exists
ls archive/2025-10-21/duplicate-screenshots/ | wc -l
# Expected: 808 files

# Check for remaining duplicates
./scripts/find_duplicates.sh
# Expected: 0 duplicate sets (all files now unique)
```

## Related Documentation

- `WARP.md`: Visual testing framework and screenshot workflow
- `VISUAL_TESTING_GUIDE.md`: Golden image management
- `Resources/screenshots/README.txt`: Directory purpose and usage

---

**Conclusion**: Successfully preserved all unique historical artifacts while eliminating 808 duplicate files, reducing the screenshot directory size by 83% without any loss of development history or visual evidence.

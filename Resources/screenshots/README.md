# Screenshot Archive

This directory contains historical visual artifacts documenting the evolution of the Metal Shader MCP project.

## Purpose

Screenshots in this directory serve as **historical documentation** of:
- Shader development progress
- UI/UX evolution
- Visual regression baselines
- Animation sequences
- Bug fixes and improvements

## Organization

### Animation Sequences
Files named `YYYY-MM-DD_HH-MM-SS_animation_sequence_frame_NNNN_tT.TTT.png`:
- `NNNN`: Frame number (0000-0149)
- `T.TTT`: Timestamp in seconds
- Captures shader animations at 30fps
- Oldest occurrence of each unique frame is preserved

### Development Screenshots  
Files named `YYYY-MM-DD_HH-MM-SS_description.png`:
- Key UI milestones
- Feature demonstrations
- Bug verification captures
- Test tokens and exports

### Test Output (Gitignored)
`tests/` subdirectory contains test artifacts:
- Visual regression test diffs
- Actual vs expected comparisons
- Automatically regenerated during test runs
- Not tracked in git (ephemeral)

## Deduplication

**Last Deduplication**: 2025-10-21
- **Before**: 1,050 files
- **After**: 171 unique files (83% reduction)
- **Archived**: 808 duplicate files moved to `archive/2025-10-21/duplicate-screenshots/`
- **Scripts**: See `scripts/find_duplicates.sh` and `scripts/archive_duplicates.sh`

See `docs/SCREENSHOT_DEDUPLICATION.md` for detailed deduplication history.

## Best Practices

### When to Add Screenshots
1. **New Features**: Capture UI when feature is complete
2. **Bug Fixes**: Before/after screenshots for visual issues
3. **Shader Changes**: Animation sequences or single frames
4. **Milestones**: Significant project achievements

### Naming Convention
```
YYYY-MM-DD_HH-MM-SS_descriptive_name.png
```
- Use timestamps to ensure uniqueness
- Use descriptive names that explain what is shown
- Use underscores, not spaces
- Keep names concise but meaningful

### File Size Considerations
- **Target**: < 500KB per screenshot
- **Format**: PNG (lossless, good for UI/shaders)
- **Resolution**: Match actual display resolution
- **Optimization**: Run `pngcrush` or similar if needed

## Maintenance

### Monthly Deduplication
```bash
# Find duplicates
./scripts/find_duplicates.sh

# Review duplicates_report.txt

# Archive duplicates
./scripts/archive_duplicates.sh
```

### Cleanup Policy
- Keep all unique frames from animation sequences
- Keep all milestone screenshots indefinitely  
- Archive duplicates, don't delete (they might have historical context)
- Review archive directory quarterly for compression/removal

## Related Documentation

- `WARP.md`: Visual testing workflow and screenshot capture procedures
- `VISUAL_TESTING_GUIDE.md`: Golden image testing and visual regression
- `docs/SCREENSHOT_DEDUPLICATION.md`: Detailed deduplication history
- `scripts/screenshot_app.sh`: Automated screenshot capture script

---

**Note**: This directory is tracked in git to preserve project history. Test output in `tests/` is gitignored as it's regenerated during test runs.

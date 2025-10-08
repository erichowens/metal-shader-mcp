# Regenerate golden images used in visual regression tests
# Usage:
#   make regen-goldens

.PHONY: regen-goldens

regen-goldens:
	@echo "Rebuilding golden images..."
	@mkdir -p Tests/MetalShaderTests/Fixtures
	@swift run ShaderRenderCLI --shader-file Tests/MetalShaderTests/Fixtures/constant_color.metal \
		--out Tests/MetalShaderTests/Fixtures/golden_constant_color.png --width 64 --height 64
	@swift run ShaderRenderCLI --shader-file Tests/MetalShaderTests/Fixtures/gradient.metal \
		--out Tests/MetalShaderTests/Fixtures/golden_gradient.png --width 64 --height 64
	@echo "Done. Goldens refreshed."

.PHONY: regen-goldens-all clean-visuals

regen-goldens-all:
	@echo "Rebuilding golden images for multiple resolutions..."
	@mkdir -p Tests/MetalShaderTests/Fixtures
	@for RES in 64 128 256; do \
		w=$$RES; h=$$RES; \
		echo "  -> $$w x $$h"; \
		swift run ShaderRenderCLI --shader-file Tests/MetalShaderTests/Fixtures/constant_color.metal \
			--out Tests/MetalShaderTests/Fixtures/golden_constant_color_$${w}x$${h}.png --width $$w --height $$h; \
		swift run ShaderRenderCLI --shader-file Tests/MetalShaderTests/Fixtures/gradient.metal \
			--out Tests/MetalShaderTests/Fixtures/golden_gradient_$${w}x$${h}.png --width $$w --height $$h; \
	done
	@echo "Done. Multi-resolution goldens refreshed."

clean-visuals:
	@echo "Cleaning visual test artifacts..."
	@rm -rf Resources/screenshots/tests || true
	@mkdir -p Resources/screenshots/tests
	@echo "Done. Visual artifacts cleaned."

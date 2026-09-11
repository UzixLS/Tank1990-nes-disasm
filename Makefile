-include Makefile.local

PYTHON ?= python
CA65 ?= ca65
LD65 ?= ld65
MKDIR_P ?= mkdir -p
RM_RF ?= rm -rf
BUILD := build
TARGET := $(BUILD)/tank1990-ch.nes
ORIGINAL := Tank 1990 (Ch).nes

.PHONY: all verify audit test clean

all: $(TARGET)

$(BUILD):
	$(MKDIR_P) $@

$(BUILD)/sprites.chr: assets/chr/sprites.bmp tools/chr.py | $(BUILD)
	$(PYTHON) tools/chr.py encode $< $@

$(BUILD)/background.chr: assets/chr/background.bmp tools/chr.py | $(BUILD)
	$(PYTHON) tools/chr.py encode $< $@

$(BUILD)/sprite-palette.bin: assets/palettes/sprites.pal tools/palettes.py | $(BUILD)
	$(PYTHON) tools/palettes.py $< 16 $@

$(BUILD)/background-palettes.bin: assets/palettes/background.pal tools/palettes.py | $(BUILD)
	$(PYTHON) tools/palettes.py $< 144 $@

$(BUILD)/background-metatiles.bin: assets/metatiles/background.tsa tools/metatiles.py | $(BUILD)
	$(PYTHON) tools/metatiles.py $< $@

$(BUILD)/tank-levels.bin: $(wildcard assets/levels/tank/*.map) tools/levels.py | $(BUILD)
	$(PYTHON) tools/levels.py encode assets/levels/tank 100 $@

$(BUILD)/extra-levels.bin: $(wildcard assets/levels/extra/*.map) tools/levels.py | $(BUILD)
	$(PYTHON) tools/levels.py encode assets/levels/extra 5 $@

$(BUILD)/classic-levels.bin: $(wildcard assets/levels/classic/*.map) tools/levels.py | $(BUILD)
	$(PYTHON) tools/levels.py encode assets/levels/classic 36 $@

$(BUILD)/unused-level-a800.bin: assets/levels/unused/001.map tools/levels.py | $(BUILD)
	$(PYTHON) tools/levels.py encode assets/levels/unused 1 $@

ASM_SOURCES := src/main.s src/hardware.inc src/ram.inc src/game.inc src/header.s src/levels.s src/prg0_rest.s \
	src/extra_levels.s src/prg0_extensions.s src/prg0_unreferenced_data.s \
	src/deferred_integrity_bridge.s src/prg0_extension_prototypes.s \
	src/prg1_lo.s src/game_flow.s src/startup.s src/decimal.s src/construction_editor.s \
	src/battle_flow.s src/session_init.s src/gameplay_tick.s src/stage_runtime.s \
	src/attract_mode.s src/session_result.s src/variant_selection.s src/gameplay_runtime_data.s \
	src/flow_helpers.s src/powerup_flow.s src/attract_ai.s src/construction_cursor.s \
	src/stage_outcome.s src/frontend_misc.s src/battle_hud_runtime.s \
	src/construction_cursor_bounds.s src/battle_overlays.s src/screens.s \
	src/title_menu.s src/battle_hud.s src/base_render.s src/screen_transitions.s \
	src/stage_statistics.s src/title_render.s src/legacy_screen_stream.s \
	src/statistics_delay.s src/screen_text_data.s src/screen_misc_text.s src/battle_ui_data.s \
	src/direction_tables.s src/powerup_effect0.s src/score_rewards.s \
	src/runtime_checksum_init.s src/remainder.s \
	src/ppu.s src/nmi.s src/random.s src/ppu_display.s src/runtime_init.s \
	src/palette.s src/ppu_attributes.s src/input.s src/ppu_queues.s \
	src/terrain_shadow.s src/nametable_shadow.s src/metatile_render.s src/chr_raster.s \
	src/ppu_sync.s src/score.s \
	src/oam.s src/math.s src/metatile_data.s src/tanks.s src/tank_player_audio.s \
	src/enemy_tank_spawn.s \
	src/tank_player_input.s src/tank_update.s src/tank_navigation.s src/tank_targeting.s \
	src/tank_lifecycle.s src/enemy_tank_ai.s src/tank_render.s \
	src/projectiles.s src/tank_occupancy.s src/battle_effects.s \
	src/tank_spawn.s src/powerup_effect1.s src/variant_ui_logic.s src/object_state_helpers.s \
	src/stage_catalog.s src/variant_metadata_helpers.s src/input_direction.s src/tank_tables.s \
	src/tank_init.s src/powerup_pickup_entry.s src/score_awards.s src/variant_ui_data.s \
	src/collisions.s src/projectile_terrain_collisions.s src/projectile_tank_collisions.s \
	src/variant_menu_data.s src/enemy_score_awards.s src/powerup_spawn.s \
	src/projectile_pair_collisions.s src/powerup_pickup.s src/stage_selection_helpers.s \
	src/maximum_upgrade_trampoline.s src/projectile_terrain_classifier.s \
	src/upgrade_state_helper.s src/audio_state_helper.s src/projectile_direction_tables.s \
	src/audio.s src/audio_engine.s src/audio_data.s src/stage_loader.s src/prg1_hi.s \
	src/frontend_extensions.s src/runtime_integrity.s \
	src/powerup_effects_hi.s src/tank1990_extensions.s src/collision_extensions.s \
	src/projectile_variant.s src/chr.s

$(BUILD)/tank1990.o: $(ASM_SOURCES) $(BUILD)/tank-levels.bin $(BUILD)/extra-levels.bin $(BUILD)/classic-levels.bin $(BUILD)/unused-level-a800.bin $(BUILD)/sprites.chr $(BUILD)/background.chr $(BUILD)/sprite-palette.bin $(BUILD)/background-palettes.bin $(BUILD)/background-metatiles.bin | $(BUILD)
	$(CA65) -g -o $@ $<

$(TARGET): $(BUILD)/tank1990.o cfg/tank1990.cfg
	$(LD65) -C cfg/tank1990.cfg -m $(BUILD)/tank1990.map -Ln $(BUILD)/tank1990.lbl -o $@ $<

verify: $(TARGET)
	$(PYTHON) tools/rom.py verify $(TARGET) "$(ORIGINAL)"

audit: verify
	$(PYTHON) tools/rom.py extract "$(ORIGINAL)" $(BUILD)/original

test: verify
	$(PYTHON) -m unittest discover -s tests -v

clean:
	$(RM_RF) $(BUILD)

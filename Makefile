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
	src/prg1_lo.s src/game_flow.s src/decimal.s src/powerup_flow.s src/screens.s \
	src/title_menu.s src/base_render.s src/stage_statistics.s src/title_render.s \
	src/direction_tables.s src/powerup_effect0.s src/score_rewards.s \
	src/runtime_checksum_init.s src/remainder.s \
	src/ppu.s src/runtime_init.s src/input.s src/score.s \
	src/oam.s src/math.s src/tanks.s src/projectiles.s src/tank_occupancy.s src/battle_effects.s \
	src/tank_spawn.s src/powerup_effect1.s src/variant_ui_logic.s src/object_state_helpers.s \
	src/stage_catalog.s src/variant_metadata_helpers.s src/input_direction.s src/tank_tables.s \
	src/tank_init.s src/powerup_pickup_entry.s src/score_awards.s src/variant_ui_data.s \
	src/collisions.s src/variant_menu_data.s src/powerup_spawn.s \
	src/powerup_pickup.s src/stage_selection_helpers.s \
	src/audio.s src/stage_loader.s src/prg1_hi.s src/frontend_extensions.s src/runtime_integrity.s \
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

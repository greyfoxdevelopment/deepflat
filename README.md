# DeepFlat (NeoForge, Minecraft 1.21.1)

Standalone, data-only NeoForge mod converted from the DeepFlat Create Edition datapack. It adds four world types to the normal **Create New World → World Type** button. No datapack install, no other mods (Create is **not** required and not referenced).

- Minecraft **1.21.1**, NeoForge **21.1.248** (declared range `[21.1.248,21.2)`)
- Install: drop `deepflat-1.21.1-neoforge-1.0.0.jar` in `mods/` (client, and server for dedicated servers). Create a **new** world; choose the type under **World Type** (not Superflat).

| World type | Behaviour |
|---|---|
| DeepFlat | Fixed Plains biome, flat surface at Y=68, deepslate below Y=1 / stone above, caves, ores. |
| DeepFlat Biome Flat | Vanilla `multi_noise` overworld biomes on flat Y=68 terrain; ocean biomes are dry land here. |
| DeepFlat Flat Oceans | Flat Y=68 land, ocean basins (down to ~Y=32), lower river channels, sea level Y=63. |
| DeepFlat Biome Terrain | Vanilla overworld noise settings and biomes. |

## How it works
Everything is data-driven (`src/main/resources/data/deepflat/worldgen/...`): noise settings, density functions, carvers, one fixed biome, and four world presets. `data/minecraft/tags/worldgen/world_preset/normal.json` adds the presets to the world-type button; `assets/deepflat/lang/en_us.json` provides their names. Mod data is loaded automatically as a built-in pack. Because there is no Java code, the mod uses NeoForge's `lowcodefml` loader.

## Build
```
gradle jar            # Gradle 8.x, JDK 21; output: build/libs/deepflat-1.21.1-neoforge-1.0.0.jar
python3 -I scripts/validate.py [path/to/jar]   # static checks
```
(`./gradlew` is included but needs network access to download Gradle.)

## Verification status — read this
Done: Gradle jar build; JSON syntax; all 30 `deepflat:` references resolve; presets/tag/lang consistent; mod metadata; no Create dependency; no class files.
**NOT done (needs in-game testing):** loading in Minecraft/NeoForge, the world-type menu, any generated terrain, caves, ores, oceans, rivers, structures, strongholds/End Portal, chunk borders, server start. The original datapack author also never ran it in-game, so the generation numbers (cave thresholds, Y=68 land, ocean profile, rivers) are unproven.

## Known limitations / risks
- Not compiled against NeoForge (no Java); `lowcodefml` + `pack.mcmeta` formats follow NeoForge 21.1 conventions but were not launched.
- Structures rely on vanilla tags: in Classic, `deepflat:flatlands` is added to village/outpost/ruined-portal/trial-chamber/stronghold tags only. Structures in the flat modes are untested; terrain flatness may affect some placements.
- Datapack presets have no sliders; values are fixed.
- Optional Create compatibility: none implemented (vanilla blocks only).

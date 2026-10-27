#!/usr/bin/env python3
"""Static validation of DeepFlat's bundled data. Run: python3 -I scripts/validate.py [jar]
Checks JSON syntax, deepflat:* reference resolution, preset/tag consistency, mod metadata,
and that no Create dependency exists. It cannot check vanilla registry codecs."""
import json, re, sys, zipfile, pathlib

root = pathlib.Path(__file__).resolve().parent.parent / "src/main/resources"
files = {}
if len(sys.argv) > 1:
    with zipfile.ZipFile(sys.argv[1]) as z:
        for n in z.namelist():
            if not n.endswith("/"): files[n] = z.read(n).decode()
else:
    for p in root.rglob("*"):
        if p.is_file(): files[str(p.relative_to(root)).replace("\\", "/")] = p.read_text()

errors = []
parsed = {}
for n, t in files.items():
    if n.endswith(".json") or n.endswith(".mcmeta"):
        try: parsed[n] = json.loads(t)
        except Exception as e: errors.append(f"bad JSON {n}: {e}")

def ids(kind):
    return {f"deepflat:{m.group(1)}" for n in parsed
            if (m := re.fullmatch(rf"data/deepflat/worldgen/{kind}/(.+)\.json", n))}
have = {k: ids(k) for k in ["biome","density_function","noise_settings","world_preset","configured_carver"]}

refs = []
def walk(o, path):
    if isinstance(o, dict):
        for k, v in o.items(): walk(v, path)
    elif isinstance(o, list):
        for v in o: walk(v, path)
    elif isinstance(o, str) and o.startswith("deepflat:"): refs.append((path, o))
for n, d in parsed.items(): walk(d, n)

allids = set().union(*have.values())
for path, r in refs:
    if r not in allids: errors.append(f"unresolved {r} in {path}")

tag = parsed.get("data/minecraft/tags/worldgen/world_preset/normal.json", {})
for p in have["world_preset"]:
    if p not in tag.get("values", []): errors.append(f"preset {p} missing from minecraft:normal tag")
for v in tag.get("values", []):
    if v not in have["world_preset"]: errors.append(f"tag lists unknown preset {v}")
for p in have["world_preset"]:
    lang = parsed.get("assets/deepflat/lang/en_us.json", {})
    k = "generator." + p.replace(":", ".")
    if k not in lang: errors.append(f"missing lang key {k}")

toml = files.get("META-INF/neoforge.mods.toml", "")
if not toml: errors.append("missing neoforge.mods.toml")
if re.search(r"create", toml, re.I): errors.append("Create referenced in mods.toml")
if "21.1.248" not in toml: errors.append("NeoForge 21.1.248 bound missing")
if any(n.endswith(".class") for n in files): errors.append("unexpected class files")

for n in ("data/deepflat/worldgen/noise_settings/flat_biomes.json","data/deepflat/worldgen/noise_settings/flat_oceans.json","data/deepflat/worldgen/noise_settings/deepflat.json"):
    d = parsed.get(n, {})
    if d.get("noise",{}).get("min_y") != -64 or d.get("noise",{}).get("height") != 384: errors.append(f"{n}: unexpected world height")
    if d.get("sea_level") != 63: errors.append(f"{n}: sea_level != 63")

print(f"files={len(files)} json={len(parsed)} deepflat_refs={len(refs)} presets={sorted(have['world_preset'])}")
print("ERRORS:" if errors else "OK: no static errors", *errors, sep="\n")
sys.exit(1 if errors else 0)

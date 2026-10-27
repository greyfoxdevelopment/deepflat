param(
  [string]$PackRoot = $PSScriptRoot,
  [string]$ZipPath = ""
)

$ErrorActionPreference = "Stop"
$PackRoot = [System.IO.Path]::GetFullPath($PackRoot)
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-RequiredFile([string]$RelativePath) {
  $path = Join-Path $PackRoot $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    $failures.Add("Missing required file: $RelativePath")
  }
}

@(
  "pack.mcmeta",
  "data\deepflat\worldgen\world_preset\deepflat.json",
  "data\deepflat\worldgen\world_preset\biome_flat.json",
  "data\deepflat\worldgen\world_preset\flat_oceans.json",
  "data\deepflat\worldgen\world_preset\biome_terrain.json",
  "data\deepflat\worldgen\noise_settings\deepflat.json",
  "data\deepflat\worldgen\noise_settings\flat_biomes.json",
  "data\deepflat\worldgen\noise_settings\flat_oceans.json",
  "data\deepflat\worldgen\biome\flatlands.json",
  "data\deepflat\worldgen\density_function\flat_profile.json",
  "data\deepflat\worldgen\density_function\cave_mask.json",
  "data\deepflat\worldgen\density_function\cave_density.json",
  "data\deepflat\worldgen\density_function\flat_ocean_density.json",
  "data\deepflat\worldgen\density_function\ocean_basin_profile.json",
  "data\deepflat\worldgen\density_function\river_basin_profile.json",
  "data\deepflat\worldgen\configured_carver\cave.json",
  "data\deepflat\worldgen\configured_carver\cave_extra_underground.json",
  "data\deepflat\worldgen\configured_carver\canyon.json",
  "data\minecraft\tags\worldgen\world_preset\normal.json",
  "docs\vanilla_overworld_biomes_1.21.1.json",
  "package.ps1",
  "README.md"
) | ForEach-Object { Assert-RequiredFile $_ }

$metaPath = Join-Path $PackRoot "pack.mcmeta"
if (Test-Path -LiteralPath $metaPath -PathType Leaf) {
  $meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
  if ($meta.pack.pack_format -ne 48) {
    $failures.Add("pack.mcmeta pack_format must be 48 for Minecraft 1.21.1.")
  }
}

$jsonFiles = @(Get-ChildItem -LiteralPath $PackRoot -Filter "*.json" -File -Recurse)
foreach ($file in $jsonFiles) {
  try {
    Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json | Out-Null
  }
  catch {
    $failures.Add("Invalid JSON in $($file.FullName): $($_.Exception.Message)")
  }
}

$resourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $PackRoot "data\deepflat\worldgen") -Filter "*.json" -File -Recurse)
$customIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($file in $jsonFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($match in [regex]::Matches($content, '(?<![A-Za-z0-9_])deepflat:[a-z0-9_./-]+')) {
    [void]$customIds.Add($match.Value.Substring("deepflat:".Length))
  }
}
foreach ($id in $customIds) {
  $matches = @($resourceFiles | Where-Object {
    $relative = $_.FullName.Substring((Join-Path $PackRoot "data\deepflat\worldgen").Length).TrimStart('\')
    $relative -replace '\\', '/' -match ("/" + [regex]::Escape($id) + "\.json$")
  })
  if ($matches.Count -eq 0) {
    $failures.Add("Unresolved custom registry ID: deepflat:$id")
  }
}

$biomeManifestPath = Join-Path $PackRoot "docs\vanilla_overworld_biomes_1.21.1.json"
if (Test-Path -LiteralPath $biomeManifestPath -PathType Leaf) {
  $biomeManifest = Get-Content -LiteralPath $biomeManifestPath -Raw | ConvertFrom-Json
  if ($biomeManifest.minecraft_version -ne "1.21.1" -or $biomeManifest.count -ne 53 -or $biomeManifest.biomes.Count -ne 53) {
    $failures.Add("The vanilla 1.21.1 Overworld biome manifest must list exactly 53 biomes.")
  }
  if (@($biomeManifest.biomes | Select-Object -Unique).Count -ne 53) {
    $failures.Add("The vanilla Overworld biome manifest contains duplicate IDs.")
  }
  foreach ($caveBiome in @("minecraft:deep_dark", "minecraft:dripstone_caves", "minecraft:lush_caves")) {
    if ($biomeManifest.cave_biomes -notcontains $caveBiome -or $biomeManifest.biomes -notcontains $caveBiome) {
      $failures.Add("The biome manifest is missing cave biome $caveBiome.")
    }
  }
}

$biomePresetFiles = @(
  "data\deepflat\worldgen\world_preset\biome_flat.json",
  "data\deepflat\worldgen\world_preset\flat_oceans.json",
  "data\deepflat\worldgen\world_preset\biome_terrain.json"
)
foreach ($relativePath in $biomePresetFiles) {
  $path = Join-Path $PackRoot $relativePath
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    $preset = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $generator = $preset.dimensions."minecraft:overworld".generator
    if ($generator.biome_source.type -ne "minecraft:multi_noise" -or $generator.biome_source.preset -ne "minecraft:overworld") {
      $failures.Add("World preset $relativePath must use the vanilla multi-noise Overworld biome source.")
    }
    if ($preset.dimensions."minecraft:the_end".generator.type -ne "minecraft:noise" -or $preset.dimensions."minecraft:the_end".generator.settings -ne "minecraft:end") {
      $failures.Add("World preset $relativePath must preserve the vanilla End generator.")
    }
    if ($preset.dimensions."minecraft:the_nether".generator.type -ne "minecraft:noise" -or $preset.dimensions."minecraft:the_nether".generator.settings -ne "minecraft:nether") {
      $failures.Add("World preset $relativePath must preserve the vanilla Nether generator.")
    }
  }
}

$expectedNoiseSettings = @{
  "flat_biomes" = "deepflat:cave_mask"
  "flat_oceans" = "deepflat:flat_ocean_density"
}
foreach ($settingsName in $expectedNoiseSettings.Keys) {
  $path = Join-Path $PackRoot "data\deepflat\worldgen\noise_settings\$settingsName.json"
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    $settings = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($settings.noise_router.final_density -ne $expectedNoiseSettings[$settingsName]) {
      $failures.Add("$settingsName noise settings point to the wrong final-density function.")
    }
    foreach ($climateField in @("continents", "depth", "erosion", "ridges", "temperature", "vegetation")) {
      if ($settings.noise_router.$climateField -eq "minecraft:zero") {
        $failures.Add("$settingsName has a disabled vanilla climate field: $climateField.")
      }
    }
  }
}

$presetTagPath = Join-Path $PackRoot "data\minecraft\tags\worldgen\world_preset\normal.json"
if (Test-Path -LiteralPath $presetTagPath -PathType Leaf) {
  $presetTag = Get-Content -LiteralPath $presetTagPath -Raw | ConvertFrom-Json
  foreach ($worldPreset in @("deepflat:deepflat", "deepflat:biome_flat", "deepflat:flat_oceans", "deepflat:biome_terrain")) {
    if ($presetTag.values -notcontains $worldPreset) {
      $failures.Add("The minecraft:normal world-preset tag does not include $worldPreset.")
    }
  }
}

$biomePath = Join-Path $PackRoot "data\deepflat\worldgen\biome\flatlands.json"
if (Test-Path -LiteralPath $biomePath -PathType Leaf) {
  $biome = Get-Content -LiteralPath $biomePath -Raw | ConvertFrom-Json
  $requiredFeatures = @(
    "minecraft:ore_coal_upper",
    "minecraft:ore_copper",
    "minecraft:ore_iron_middle",
    "minecraft:ore_gold",
    "minecraft:ore_redstone",
    "minecraft:ore_lapis",
    "minecraft:ore_diamond",
    "minecraft:ore_granite_upper",
    "minecraft:ore_diorite_upper",
    "minecraft:ore_andesite_upper",
    "minecraft:monster_room"
  )
  $allFeatures = @($biome.features | ForEach-Object { $_ })
  foreach ($feature in $requiredFeatures) {
    if ($allFeatures -notcontains $feature) {
      $failures.Add("Required vanilla biome feature is missing: $feature")
    }
  }
  foreach ($carver in @("deepflat:cave", "deepflat:cave_extra_underground", "deepflat:canyon")) {
    if ($biome.carvers.air -notcontains $carver) {
      $failures.Add("Configured cave carver is not assigned to the biome: $carver")
    }
  }
}

if ($ZipPath) {
  $ZipPath = [System.IO.Path]::GetFullPath($ZipPath)
  if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
    $failures.Add("ZIP does not exist: $ZipPath")
  }
  else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
      $names = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
      if ($names -notcontains "pack.mcmeta") {
        $failures.Add("ZIP must have pack.mcmeta at its root.")
      }
      if ($names -notcontains "data/deepflat/worldgen/world_preset/deepflat.json") {
        $failures.Add("ZIP is missing the root-level DeepFlat world preset.")
      }
      if ($names -notcontains "data/deepflat/worldgen/world_preset/biome_flat.json") {
        $failures.Add("ZIP is missing the flat-biome world preset.")
      }
      if ($names -notcontains "docs/vanilla_overworld_biomes_1.21.1.json") {
        $failures.Add("ZIP is missing the vanilla biome coverage manifest.")
      }
    }
    finally {
      $archive.Dispose()
    }
  }
}

if ($failures.Count -gt 0) {
  $failures | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Output "PASS: $($jsonFiles.Count) JSON files parsed."
Write-Output "PASS: pack format 48 and required datapack files are present."
Write-Output "PASS: all custom registry IDs resolve to datapack resources."
Write-Output "PASS: vanilla 1.21.1 biome manifest and climate-based world presets are present."
Write-Output "PASS: flat-mode climate routers and Nether/End generators are preserved."
Write-Output "PASS: preset tag, underground ores, stone variants, and carvers are present."
if ($ZipPath) {
  Write-Output "PASS: ZIP has pack.mcmeta and the custom preset at its root."
}

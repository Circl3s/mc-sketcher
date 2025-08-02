#! /usr/bin/pwsh

Param(
    [string]$Path = ".\images",
    [int]$MaxSize = 4,
    [switch]$Smooth = $False,
    [switch]$VanillaThumbnails = $False,
    [switch]$Interpolate = $False
)

if (-Not (Get-Command ffmpeg -ErrorAction Ignore)) {
    Write-Error "It seems you don't have ffmpeg installed or it isn't in your PATH. Aborting."
    Exit
}

if (-Not (Get-Command 7z -ErrorAction Ignore)) {
    Write-Error "It seems you don't have ffmpeg installed or it isn't in your PATH. Aborting."
    Exit
}

$Images = Get-ChildItem $Path
$Paintings = @()

#? Reset working directory
New-Item ".\working" -ItemType Directory -ErrorAction Ignore
Remove-Item ".\working\*" -Recurse

Copy-Item ".\assets\datapack_template" ".\working\datapack" -Recurse
Copy-Item ".\assets\resourcepack_template" ".\working\resourcepack" -Recurse
Copy-Item ".\assets\resourcepack_template" ".\working\resourcepack_x32" -Recurse
Copy-Item ".\assets\resourcepack_template" ".\working\resourcepack_hd" -Recurse

Remove-Item ".\working\*" -Include "*.gitkeep" -Recurse

#? Data-driven painting item texture base
$ItemModel = @{
    model = @{
        type = "minecraft:select"
        property = "minecraft:component"
        component = "minecraft:painting/variant"
        cases = @()
        fallback = @{
            type = "minecraft:model"
            model = "minecraft:item/painting"
        }
    }
}

ForEach ($Image in $Images) {
    $Author = ($Image.BaseName -split " - ")[0]
    $Title = ($Image.BaseName -split " - ")[1]
    $Filename = "$($Author)_$Title".toLower().Replace(" ", "_").Replace("-", "_")
    $Resolution = (ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $Image.FullName) -split "x"
    $Frames = (ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -print_format default=nokey=1:noprint_wrappers=1 $Image.FullName)
    $Animated = $Frames -gt 1
    $Ratio = $Resolution[0] / $Resolution[1]

    #? Find best painting size
    $BestSize = @(0, 0)
    if ($Null -eq ($Image.BaseName -split " - ")[2]) {
        $SmallestDifference = [decimal]::MaxValue
        for ($x = 1; $x -le $MaxSize; $x++) {
            for ($y = 1; $y -le $MaxSize; $y++) {
                $Diff = ($x / $y) - $Ratio
                if ([Math]::Abs($Diff) -lt [Math]::Abs($SmallestDifference)) {
                    $BestSize = @($x, $y)
                    $SmallestDifference = $Diff
                }
            }
        }
    } else {
        $BestSize = [int[]](($Image.BaseName -split " - ")[2] -split "x")
        $SmallestDifference = ($BestSize[0] / $BestSize[1]) - $Ratio
    }
    
    #? Find crop resolution and direction
    $NewResolution = $Resolution.Clone()
    if ([Math]::Abs($SmallestDifference) -gt 0.02) {
        if ($SmallestDifference -lt 0) {    #* Too wide
            $NewResolution[0] = [Math]::Round($BestSize[0] * ($NewResolution[1] / $BestSize[1]))
        } else {                            #* Too tall
            $NewResolution[1] = [Math]::Round($BestSize[1] * ($NewResolution[0] / $BestSize[0]))
        }
    }

    Write-Output $Image.BaseName
    Write-Host "Optimal painting size: $BestSize"
    Write-Output "Difference from painting aspect ratio: $SmallestDifference ($Resolution -> $NewResolution)"
    $EstimatedFrames = 1
    if ($Animated) {
        $Duration = [double](ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $Image.FullName)
        $EstimatedFrames = [Math]::Floor($Duration * 10)
        if ($EstimatedFrames -ge $Frames) {
            $EstimatedFrames -= 1
        }
        Write-Output "Estimated frames at 10fps: $EstimatedFrames"
    }
    Write-Output "---"
    

    #? Generate painting textures
    #* HD (crop only)
    ffmpeg -v error -i $Image.FullName -vf "crop=$($NewResolution[0]):$($NewResolution[1]), scale=$($BestSize[0] * 256):$($BestSize[1] * 256)$(if ($Animated) {", fps=10, tile=1x$EstimatedFrames"})" -frames:v 1 -update 1 ".\working\resourcepack_hd\assets\sketcher\textures\painting\$Filename.png"
    #* x16
    ffmpeg -v error -i $Image.FullName -vf "crop=$($NewResolution[0]):$($NewResolution[1]), scale=$($BestSize[0] * 16):$($BestSize[1] * 16):flags=$(if ($Smooth) {'bicubic'} else {'neighbor'})$(if ($Animated) {", fps=10, tile=1x$EstimatedFrames"})" -frames:v 1 -update 1 ".\working\resourcepack\assets\sketcher\textures\painting\$Filename.png"
    #* x32
    ffmpeg -v error -i $Image.FullName -vf "crop=$($NewResolution[0]):$($NewResolution[1]), scale=$($BestSize[0] * 32):$($BestSize[1] * 32):flags=$(if ($Smooth) {'bicubic'} else {'neighbor'})$(if ($Animated) {", fps=10, tile=1x$EstimatedFrames"})" -frames:v 1 -update 1 ".\working\resourcepack_x32\assets\sketcher\textures\painting\$Filename.png"

    #? Generate item textures
    #* HD
    ffmpeg -v error -i $Image.FullName -vf "crop=$($NewResolution[0]):$($NewResolution[1]), scale=512:512:force_original_aspect_ratio=decrease, format=rgba, pad=512:512:-1:-1:color=0x00000000" -frames:v 1 -update 1 ".\working\resourcepack_hd\assets\sketcher\textures\item\painting\$Filename.png"
    #* x16
    ffmpeg -v error -i $Image.FullName -vf "crop=$($NewResolution[0]):$($NewResolution[1]), scale=16:16:force_original_aspect_ratio=decrease:flags=$(if ($Smooth) {'bicubic'} else {'neighbor'}), format=rgba, pad=16:16:-1:-1:color=0x00000000" -frames:v 1 -update 1 ".\working\resourcepack\assets\sketcher\textures\item\painting\$Filename.png"
    #* x32
    ffmpeg -v error -i $Image.FullName -vf "crop=$($NewResolution[0]):$($NewResolution[1]), scale=32:32:force_original_aspect_ratio=decrease:flags=$(if ($Smooth) {'bicubic'} else {'neighbor'}), format=rgba, pad=32:32:-1:-1:color=0x00000000" -frames:v 1 -update 1 ".\working\resourcepack_x32\assets\sketcher\textures\item\painting\$Filename.png"

    if ($Animated) {
        $16Metadata = @{
            animation = @{
                interpolate = $Interpolate.IsPresent
                frametime = 2
                width = $BestSize[0] * 16
                height = $BestSize[1] * 16
            }
        }
        $16MetadataJSON = $16Metadata | ConvertTo-Json -Depth 10
        $16MetadataJSON | Out-File ".\working\resourcepack\assets\sketcher\textures\painting\$Filename.png.mcmeta" -Encoding utf8

        $32Metadata = @{
            animation = @{
                interpolate = $Interpolate.IsPresent
                frametime = 2
                width = $BestSize[0] * 32
                height = $BestSize[1] * 32
            }
        }
        $32MetadataJSON = $32Metadata | ConvertTo-Json -Depth 10
        $32MetadataJSON | Out-File ".\working\resourcepack_x32\assets\sketcher\textures\painting\$Filename.png.mcmeta" -Encoding utf8

        $256Metadata = @{
            animation = @{
                interpolate = $Interpolate.IsPresent
                frametime = 2
                width = $BestSize[0] * 256
                height = $BestSize[1] * 256
            }
        }
        $256MetadataJSON = $256Metadata | ConvertTo-Json -Depth 10
        $256MetadataJSON | Out-File ".\working\resourcepack_hd\assets\sketcher\textures\painting\$Filename.png.mcmeta" -Encoding utf8
    }

    #? Generate variant JSONs
    $Painting = @{
        asset_id = "sketcher:$Filename"
        author = @{
            text = $Author
            color = "gray"
        }
        title = @{
            text = $Title
            color = "yellow"
        }
        width = $BestSize[0]
        height = $BestSize[1]
    }
    $Paintings += $Painting

    $PaintingJSON = $Painting | ConvertTo-Json
    $PaintingJSON | Out-File ".\working\datapack\data\sketcher\painting_variant\$Filename.json" -Encoding utf8

    #? Add crafting recipes for variants
    $RecipeJSON = (Get-Content ".\assets\recipe_template.json").Replace("$", $Painting.asset_id)
    $RecipeJSON | Out-File ".\working\datapack\data\sketcher\recipe\$Filename.json" -Encoding utf8

    #? Add item texture
    $ItemModel.model.cases += @{
        when = $Painting.asset_id
        model = @{
            type = "minecraft:model"
            model = "sketcher:item/painting/$Filename"
        }
    }

    $Model = @{
        parent = "minecraft:item/generated"
        textures = @{
            layer0 = "sketcher:item/painting/$Filename"
        }
    }

    $ModelJSON = $Model | ConvertTo-Json
    $ModelJSON | Out-File ".\working\resourcepack\assets\sketcher\models\item\painting\$Filename.json" -Encoding utf8
    $ModelJSON | Out-File ".\working\resourcepack_x32\assets\sketcher\models\item\painting\$Filename.json" -Encoding utf8
    $ModelJSON | Out-File ".\working\resourcepack_hd\assets\sketcher\models\item\painting\$Filename.json" -Encoding utf8
}

$Placeable = @{
    values = [array]($Paintings | ForEach-Object {$_.asset_id}) 
}

$TagJSON = $Placeable | ConvertTo-Json
$TagJSON | Out-File ".\working\datapack\data\minecraft\tags\painting_variant\placeable.json" -Encoding utf8

#? Add vanilla variant recipes while we're at it
$VanillaPaintings = @(
    "kebab",
    "aztec",
    "alban",
    "aztec2",
    "bomb",
    "plant",
    "wasteland",
    "meditative",
    "wanderer",
    "graham",
    "prairie_ride",
    "pool",
    "courbet",
    "sunset",
    "sea",
    "creebet",
    "match",
    "bust",
    "stage",
    "void",
    "skull_and_roses",
    "wither",
    "baroque",
    "humble",
    "bouquet",
    "cavebird",
    "cotan",
    "endboss",
    "fern",
    "owlemons",
    "sunflowers",
    "tides",
    "dennis",
    "backyard",
    "pond",
    "fighters",
    "changing",
    "finding",
    "lowmist",
    "passage",
    "skeleton",
    "donkey_kong",
    "pointer",
    "pigscene",
    "burning_skull",
    "orb",
    "unpacked",
    "earth",
    "wind",
    "fire",
    "water"
)

ForEach ($ID in $VanillaPaintings) {
    $VanillaJSON = (Get-Content ".\assets\recipe_template.json").Replace("$", $ID)
    $VanillaJSON | Out-File ".\working\datapack\data\sketcher\recipe\vanilla\$ID.json" -Encoding utf8

    #? Add item texture
    if ($VanillaThumbnails) {
        $ItemModel.model.cases += @{
            when = $ID
            model = @{
                type = "minecraft:model"
                model = "sketcher:item/painting/vanilla/$ID"
            }
        }
    
        $VanillaModel = @{
            parent = "minecraft:item/generated"
            textures = @{
                layer0 = "sketcher:item/painting/vanilla/$ID"
            }
        }
    
        $VanillaModelJSON = $VanillaModel | ConvertTo-Json
        $VanillaModelJSON | Out-File ".\working\resourcepack\assets\sketcher\models\item\painting\vanilla\$ID.json" -Encoding utf8
        $VanillaModelJSON | Out-File ".\working\resourcepack_x32\assets\sketcher\models\item\painting\vanilla\$ID.json" -Encoding utf8
        $VanillaModelJSON | Out-File ".\working\resourcepack_hd\assets\sketcher\models\item\painting\vanilla\$ID.json" -Encoding utf8

        Copy-Item ".\assets\vanilla_thumbnails\$ID.png" ".\working\resourcepack\assets\sketcher\textures\item\painting\vanilla\$ID.png"
        Copy-Item ".\assets\vanilla_thumbnails\$ID.png" ".\working\resourcepack_hd\assets\sketcher\textures\item\painting\vanilla\$ID.png"
        Copy-Item ".\assets\vanilla_thumbnails\$ID.png" ".\working\resourcepack_x32\assets\sketcher\textures\item\painting\vanilla\$ID.png"
    }
}

#? Add a variant clearing recipe
Copy-Item ".\assets\clear_variant.json" ".\working\datapack\data\sketcher\recipe\clear_variant.json"

#? Finalize custom item textures
$ItemModelJSON = $ItemModel | ConvertTo-Json -Depth 10
$ItemModelJSON | Out-File ".\working\resourcepack\assets\minecraft\items\painting.json" -Encoding utf8
$ItemModelJSON | Out-File ".\working\resourcepack_x32\assets\minecraft\items\painting.json" -Encoding utf8
$ItemModelJSON | Out-File ".\working\resourcepack_hd\assets\minecraft\items\painting.json" -Encoding utf8

#? Create final zip files
New-Item ".\build" -ItemType Directory -ErrorAction Ignore
Remove-Item ".\build\*"

7z a ".\build\MC Sketcher Datapack.zip" .\working\datapack\*
7z a ".\build\MC Sketcher Paintings x16.zip" .\working\resourcepack\*
7z a ".\build\MC Sketcher Paintings x32.zip" .\working\resourcepack_x32\*
7z a ".\build\MC Sketcher Paintings HD.zip" .\working\resourcepack_hd\*

Write-Output "`nThe SHA1 checksums are as follows:"
Get-FileHash ".\build\MC Sketcher Datapack.zip" -Algorithm SHA1
Get-FileHash ".\build\MC Sketcher Paintings x16.zip" -Algorithm SHA1
Get-FileHash ".\build\MC Sketcher Paintings x32.zip" -Algorithm SHA1
Get-FileHash ".\build\MC Sketcher Paintings HD.zip" -Algorithm SHA1
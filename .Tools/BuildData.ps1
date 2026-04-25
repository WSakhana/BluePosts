param(
    [string]$SourcePath = "D:\BluePosts",
    [string]$OutputPath = "",
    [string]$MediaRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $PSScriptRoot "..\BluePosts_Data.lua"
}

if ([string]::IsNullOrWhiteSpace($MediaRoot)) {
    $MediaRoot = Join-Path $PSScriptRoot "..\Media\Posts"
}

try {
    Add-Type -AssemblyName System.Drawing.Common
}
catch {
    Add-Type -AssemblyName System.Drawing
}

function New-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Clear-DirectoryContents {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    Get-ChildItem -LiteralPath $Path -Force | Remove-Item -Recurse -Force
}

function Get-LuaString {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return '""'
    }

    $escaped = $Value.Replace("\", "\\").Replace('"', '\"')
    $escaped = $escaped.Replace("`r", "").Replace("`n", "\n").Replace("`t", "\t")
    return '"' + $escaped + '"'
}

function Get-CleanText {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ""
    }

    $text = [System.Net.WebUtility]::HtmlDecode($Value)
    $text = $text -replace "\s+", " "
    return $text.Trim()
}

function Get-NextPowerOfTwo {
    param([int]$Value)

    $power = 1
    while ($power -lt $Value) {
        $power *= 2
    }
    return [Math]::Max(16, $power)
}

function Save-Jpeg {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path
    )

    $directory = Split-Path -Parent $Path
    New-Directory $directory

    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Jpeg)
}

function Expand-EdgePadding {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$ContentWidth,
        [int]$ContentHeight
    )

    if ($ContentWidth -le 0 -or $ContentHeight -le 0) {
        return
    }

    $graphics = [System.Drawing.Graphics]::FromImage($Bitmap)

    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

        if ($ContentWidth -lt $Bitmap.Width) {
            $graphics.DrawImage(
                $Bitmap,
                [System.Drawing.Rectangle]::new($ContentWidth, 0, $Bitmap.Width - $ContentWidth, $ContentHeight),
                [System.Drawing.Rectangle]::new($ContentWidth - 1, 0, 1, $ContentHeight),
                [System.Drawing.GraphicsUnit]::Pixel
            )
        }

        if ($ContentHeight -lt $Bitmap.Height) {
            $graphics.DrawImage(
                $Bitmap,
                [System.Drawing.Rectangle]::new(0, $ContentHeight, $Bitmap.Width, $Bitmap.Height - $ContentHeight),
                [System.Drawing.Rectangle]::new(0, $ContentHeight - 1, $Bitmap.Width, 1),
                [System.Drawing.GraphicsUnit]::Pixel
            )
        }
    }
    finally {
        $graphics.Dispose()
    }
}

function Convert-ImageToJpeg {
    param(
        [string]$SourceFile,
        [string]$DestinationFile
    )

    $image = [System.Drawing.Image]::FromFile($SourceFile)

    try {
        $maxWidth = 720.0
        $maxHeight = 420.0
        $scale = [Math]::Min(1.0, [Math]::Min($maxWidth / $image.Width, $maxHeight / $image.Height))
        $drawWidth = [Math]::Max(1, [int][Math]::Round($image.Width * $scale))
        $drawHeight = [Math]::Max(1, [int][Math]::Round($image.Height * $scale))
        $texWidth = Get-NextPowerOfTwo $drawWidth
        $texHeight = Get-NextPowerOfTwo $drawHeight

        $bitmap = [System.Drawing.Bitmap]::new($texWidth, $texHeight, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)

        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::Black)
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.DrawImage($image, 0, 0, $drawWidth, $drawHeight)
            }
            finally {
                $graphics.Dispose()
            }

            Expand-EdgePadding -Bitmap $bitmap -ContentWidth $drawWidth -ContentHeight $drawHeight
            Save-Jpeg -Bitmap $bitmap -Path $DestinationFile
        }
        finally {
            $bitmap.Dispose()
        }

        return [pscustomobject]@{
            Width = $drawWidth
            Height = $drawHeight
            U = [Math]::Round($drawWidth / $texWidth, 6)
            V = [Math]::Round($drawHeight / $texHeight, 6)
        }
    }
    finally {
        $image.Dispose()
    }
}

function Add-Block {
    param(
        [System.Collections.Generic.List[object]]$Blocks,
        [string]$Type,
        [string]$Text,
        [hashtable]$Extra = @{}
    )

    $clean = Get-CleanText $Text
    if ($Type -ne "image" -and $Type -ne "hr" -and [string]::IsNullOrWhiteSpace($clean)) {
        return
    }

    if ($Type -eq "dev_note") {
        $clean = $clean -replace "^(?i:Developers.? notes:)\s*", ""
    }

    $block = [ordered]@{
        type = $Type
    }

    if ($Type -ne "image" -and $Type -ne "hr") {
        $block.text = $clean
    }

    foreach ($key in $Extra.Keys) {
        $block[$key] = $Extra[$key]
    }

    $Blocks.Add([pscustomobject]$block)
}

function Test-DeveloperNote {
    param([string]$Text)
    return $Text -match "^(?i:Developers.? notes:)"
}

function Get-InlineTextWithoutNestedLists {
    param([System.Xml.XmlNode]$Node)

    $parts = New-Object System.Collections.Generic.List[string]

    foreach ($child in $Node.ChildNodes) {
        if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element -and $child.Name.ToLowerInvariant() -eq "ul") {
            continue
        }

        if ($child.NodeType -eq [System.Xml.XmlNodeType]::Text) {
            $parts.Add($child.Value)
        }
        else {
            $parts.Add($child.InnerText)
        }
    }

    return Get-CleanText ($parts -join " ")
}

function Test-HeadingParagraph {
    param(
        [System.Xml.XmlNode]$Node,
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text) -or $Text.Length -gt 90) {
        return $false
    }

    $hasStrong = $false
    foreach ($child in $Node.ChildNodes) {
        if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element -and $child.Name.ToLowerInvariant() -eq "strong") {
            $hasStrong = $true
        }
        elseif ($child.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            return $false
        }
    }

    return $hasStrong
}

function Process-ListItem {
    param(
        [System.Xml.XmlNode]$Node,
        [System.Collections.Generic.List[object]]$Blocks,
        [int]$Level
    )

    $text = Get-InlineTextWithoutNestedLists $Node

    if (-not [string]::IsNullOrWhiteSpace($text)) {
        if (Test-DeveloperNote $text) {
            Add-Block -Blocks $Blocks -Type "dev_note" -Text $text -Extra @{ level = $Level }
        }
        else {
            Add-Block -Blocks $Blocks -Type "list_item" -Text $text -Extra @{ level = $Level }
        }
    }

    foreach ($child in $Node.ChildNodes) {
        if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element -and $child.Name.ToLowerInvariant() -eq "ul") {
            foreach ($nested in $child.ChildNodes) {
                if ($nested.NodeType -eq [System.Xml.XmlNodeType]::Element -and $nested.Name.ToLowerInvariant() -eq "li") {
                    Process-ListItem -Node $nested -Blocks $Blocks -Level ($Level + 1)
                }
            }
        }
    }
}

function Get-GeneratedImageEntry {
    param(
        [string]$SourceFile,
        [string]$PostID,
        [hashtable]$ImageCache
    )

    if (-not (Test-Path -LiteralPath $SourceFile)) {
        return $null
    }

    if (-not $ImageCache.ContainsKey($SourceFile)) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($SourceFile)
        $postMedia = Join-Path $MediaRoot $PostID
        New-Directory $postMedia
        $destFile = Join-Path $postMedia ($baseName + ".jpg")
        $result = Convert-ImageToJpeg -SourceFile $SourceFile -DestinationFile $destFile
        $relativePath = "Interface\AddOns\BluePosts\Media\Posts\$PostID\$baseName.jpg"
        $ImageCache[$SourceFile] = [pscustomobject]@{
            file = $relativePath
            width = $result.Width
            height = $result.Height
            u = $result.U
            v = $result.V
        }
    }

    return $ImageCache[$SourceFile]
}

function Process-Node {
    param(
        [System.Xml.XmlNode]$Node,
        [System.Collections.Generic.List[object]]$Blocks,
        [string]$FolderPath,
        [string]$PostID,
        [hashtable]$ImageCache
    )

    if ($Node.NodeType -ne [System.Xml.XmlNodeType]::Element) {
        return
    }

    $name = $Node.Name.ToLowerInvariant()

    switch ($name) {
        "h1" {
            Add-Block -Blocks $Blocks -Type "h1" -Text (Get-CleanText $Node.InnerText).ToUpperInvariant()
        }
        "h2" {
            Add-Block -Blocks $Blocks -Type "h2" -Text (Get-CleanText $Node.InnerText).ToUpperInvariant()
        }
        "h3" {
            Add-Block -Blocks $Blocks -Type "h3" -Text (Get-CleanText $Node.InnerText)
        }
        "h4" {
            Add-Block -Blocks $Blocks -Type "h2" -Text (Get-CleanText $Node.InnerText).ToUpperInvariant()
        }
        "hr" {
            Add-Block -Blocks $Blocks -Type "hr" -Text ""
        }
        "img" {
            $src = $Node.GetAttribute("src")
            if (-not [string]::IsNullOrWhiteSpace($src)) {
                $sourceFile = Join-Path $FolderPath $src
                $entry = Get-GeneratedImageEntry -SourceFile $sourceFile -PostID $PostID -ImageCache $ImageCache
                if ($null -ne $entry) {
                    Add-Block -Blocks $Blocks -Type "image" -Text "" -Extra @{
                        file = $entry.file
                        width = $entry.width
                        height = $entry.height
                        u = $entry.u
                        v = $entry.v
                    }
                }
            }
        }
        "p" {
            $images = $Node.SelectNodes(".//img")
            if ($images.Count -gt 0) {
                foreach ($image in $images) {
                    $src = $image.GetAttribute("src")
                    if ([string]::IsNullOrWhiteSpace($src)) {
                        continue
                    }

                    $sourceFile = Join-Path $FolderPath $src
                    $entry = Get-GeneratedImageEntry -SourceFile $sourceFile -PostID $PostID -ImageCache $ImageCache
                    if ($null -eq $entry) {
                        continue
                    }

                    Add-Block -Blocks $Blocks -Type "image" -Text "" -Extra @{
                        file = $entry.file
                        width = $entry.width
                        height = $entry.height
                        u = $entry.u
                        v = $entry.v
                    }
                }
            }
            else {
                $text = Get-CleanText $Node.InnerText
                if (Test-DeveloperNote $text) {
                    Add-Block -Blocks $Blocks -Type "dev_note" -Text $text
                }
                elseif (Test-HeadingParagraph -Node $Node -Text $text) {
                    Add-Block -Blocks $Blocks -Type "h3" -Text $text
                }
                else {
                    Add-Block -Blocks $Blocks -Type "p" -Text $text
                }
            }
        }
        "ul" {
            foreach ($child in $Node.ChildNodes) {
                if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element -and $child.Name.ToLowerInvariant() -eq "li") {
                    Process-ListItem -Node $child -Blocks $Blocks -Level 0
                }
            }
        }
        default {
            foreach ($child in $Node.ChildNodes) {
                Process-Node -Node $child -Blocks $Blocks -FolderPath $FolderPath -PostID $PostID -ImageCache $ImageCache
            }
        }
    }
}

function Convert-HtmlToBlocks {
    param(
        [string]$HtmlPath,
        [string]$FolderPath,
        [string]$PostID
    )

    $html = Get-Content -Raw -Encoding UTF8 -LiteralPath $HtmlPath
    $html = $html.Replace("&nbsp;", "&#160;")
    [xml]$doc = "<root>$html</root>"
    $blocks = [System.Collections.Generic.List[object]]::new()
    $imageCache = @{}

    foreach ($node in $doc.DocumentElement.ChildNodes) {
        Process-Node -Node $node -Blocks $blocks -FolderPath $FolderPath -PostID $PostID -ImageCache $imageCache
    }

    return $blocks
}

function Get-UnixTimestamp {
    param([object]$Value)

    if ($Value -is [datetime]) {
        return [datetimeoffset]::new($Value).ToUnixTimeSeconds()
    }

    return [datetimeoffset]::Parse([string]$Value).ToUnixTimeSeconds()
}

function Write-LuaBlock {
    param(
        [System.Text.StringBuilder]$Builder,
        [object]$Block
    )

    $null = $Builder.Append("            { type = ")
    $null = $Builder.Append((Get-LuaString $Block.type))

    if ($Block.PSObject.Properties.Name -contains "text") {
        $null = $Builder.Append(", text = ")
        $null = $Builder.Append((Get-LuaString $Block.text))
    }

    foreach ($name in @("level", "width", "height")) {
        if ($Block.PSObject.Properties.Name -contains $name) {
            $null = $Builder.Append(", $name = ")
            $null = $Builder.Append([string]$Block.$name)
        }
    }

    foreach ($name in @("u", "v")) {
        if ($Block.PSObject.Properties.Name -contains $name) {
            $null = $Builder.Append(", $name = ")
            $null = $Builder.Append(([double]$Block.$name).ToString([System.Globalization.CultureInfo]::InvariantCulture))
        }
    }

    if ($Block.PSObject.Properties.Name -contains "file") {
        $null = $Builder.Append(", file = ")
        $null = $Builder.Append((Get-LuaString $Block.file))
    }

    $null = $Builder.AppendLine(" },")
}

if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "Source path not found: $SourcePath"
}

New-Directory (Split-Path -Parent $OutputPath)
New-Directory $MediaRoot
Clear-DirectoryContents -Path $MediaRoot

$posts = New-Object System.Collections.Generic.List[object]
$folders = Get-ChildItem -LiteralPath $SourcePath -Directory | Sort-Object Name

foreach ($folder in $folders) {
    $metadataPath = Join-Path $folder.FullName "metadata.json"
    $htmlPath = Join-Path $folder.FullName "index.html"

    if (-not (Test-Path -LiteralPath $metadataPath) -or -not (Test-Path -LiteralPath $htmlPath)) {
        continue
    }

    $metadata = Get-Content -Raw -Encoding UTF8 -LiteralPath $metadataPath | ConvertFrom-Json
    $postID = if ($metadata.folder_name) { [string]$metadata.folder_name } else { $folder.Name }
    $timestamp = Get-UnixTimestamp $metadata.exported_at
    $blocks = Convert-HtmlToBlocks -HtmlPath $htmlPath -FolderPath $folder.FullName -PostID $postID

    $posts.Add([pscustomobject]@{
        id = $postID
        post_key = [string]$metadata.post_key
        title = [string]$metadata.title
        category = [string]$metadata.category
        timestamp = $timestamp
        url = [string]$metadata.source_url
        content = $blocks
    })
}

$posts = $posts | Sort-Object @{ Expression = "timestamp"; Descending = $true }, title

$builder = [System.Text.StringBuilder]::new()
$null = $builder.AppendLine("-- Generated data. Do not edit manually.")
$null = $builder.AppendLine("BluePosts_Data = {")

foreach ($post in $posts) {
    $null = $builder.AppendLine("    [" + (Get-LuaString $post.id) + "] = {")
    $null = $builder.AppendLine("        id = " + (Get-LuaString $post.id) + ",")
    $null = $builder.AppendLine("        post_key = " + (Get-LuaString $post.post_key) + ",")
    $null = $builder.AppendLine("        title = " + (Get-LuaString $post.title) + ",")
    $null = $builder.AppendLine("        category = " + (Get-LuaString $post.category) + ",")
    $null = $builder.AppendLine("        timestamp = " + [string]$post.timestamp + ",")
    $null = $builder.AppendLine("        url = " + (Get-LuaString $post.url) + ",")
    $null = $builder.AppendLine("        content = {")

    foreach ($block in $post.content) {
        Write-LuaBlock -Builder $builder -Block $block
    }

    $null = $builder.AppendLine("        },")
    $null = $builder.AppendLine("    },")
}

$null = $builder.AppendLine("}")
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath (Split-Path -Parent $OutputPath)).Path + "\" + (Split-Path -Leaf $OutputPath), $builder.ToString(), [System.Text.UTF8Encoding]::new($false))

Write-Host ("Generated {0} posts -> {1}" -f $posts.Count, (Resolve-Path -LiteralPath $OutputPath).Path)

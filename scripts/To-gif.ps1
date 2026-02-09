Param (
    [Parameter(
        Mandatory = $true,
        Position = 0)]
    [string] $file
)

$item = (Get-Item $file)
$o = $item.BaseName + ".gif"
$tmpPalette = [System.IO.Path]::GetTempFileName() + ".png"

Write-Output("Converting " + $item.Name + " -> " + $o + " using tmp palette " + $tmpPalette)

ffmpeg -i $file -v warning -vf "fps=5,scale=640:-1:flags=lanczos,palettegen" -y $tmpPalette
ffmpeg -i $file -i $tmpPalette -v warning -lavfi "fps=10,scale=640:-1:flags=lanczos,paletteuse" -an -y $o
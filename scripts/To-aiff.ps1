Param (
    [Parameter(
        Mandatory = $true,
        Position = 0)]
    [string[]] $Inputs
)

foreach ($i in $Inputs) {
    $item = (Get-Item $i)
    $o = $item.BaseName + ".aiff"
    Write-Output("Converting " + $item.Name + " -> " + $o)
    ffmpeg -i $i -hide_banner -loglevel error -f aiff -acodec pcm_s16le -write_id3v2 1 $o 
}
Param (
    [Parameter(
        Mandatory = $true,
        ValueFromRemainingArguments = $true,
        Position = 0)]
    [string[]] $Inputs
)

foreach ($i in $Inputs) {
    $item = (Get-Item -LiteralPath $i)
    $o = $item.BaseName + ".mp3"
    $dir = $item.DirectoryName
    $mp3 = $dir + "\" + $o
    Write-Output("Converting " + $item.Name + " -> " + $o + " at 160 kbs (in " + $dir + ")")
    ffmpeg -i $i -hide_banner -loglevel error -vn -ac 2 -b:a 160k $mp3 
}
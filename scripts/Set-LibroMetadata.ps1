# Renames Libro.fm story files based on the file chapters.txt which should supply a list 
# of chapter titles, one per line in order. The title and track nnumber metadata for the
# files will be set, and the files renamed in the format "# Chapter Title.mp3".
Param (
    [Parameter(
        Mandatory = $true,
        HelpMessage = "Please provide a folder path containing the audio files and a list of chapters",
        Position = 1)]
    [string] $Folder
)

function SafeName {
    param(
        [Parameter(Mandatory=$true)][string]$name
        )

    $safeName = $name -replace '[<>:"/\\|?*!]','_'
    return $safeName.Trim().TrimEnd('.')
}

$chapters = @{ }
$chapterNumber = 1
$chapterFile = Join-Path -Path $Folder -ChildPath "chapters.txt"
foreach ($line in (Get-Content -Path $chapterFile)){
    $chapters.Add($chapterNumber, $line)
    $chapterNumber++
}

$audioFiles = Get-ChildItem -Path $Folder -Filter *.mp3 | Sort-Object Name

foreach ($file in $audioFiles) {
    if ($file.Name -match '(\d+)\.mp3$') {
        $trackNumber = $Matches[1]/1
        $chapterTitle = $chapters[$trackNumber]
        $ext = $file.Extension
        $safeName = SafeName -name ("$trackNumber $chapterTitle$ext")

        $finalPath = Join-Path -Path $file.DirectoryName -ChildPath $safeName
        ffmpeg -hide_banner -loglevel error -i $file.FullName -c:a copy -metadata title=$chapterTitle -metadata track=$trackNumber $finalPath
        if (Test-Path $finalPath) {
            Remove-Item -LiteralPath $file.FullName -Force
            Write-Output("Renamed $($file.Name) to $safeName and updated metadata")
        } else {
            Write-Warning "Failed to create $finalPath. Skipping deletion of original file."
        }
    } else {
        Write-Warning "No track number found for $file. Skipping "
    }
}
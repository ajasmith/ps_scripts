param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$DestinationPath
)

# Helper function to compute relative paths cleanly across Windows/.NET constraints
function Ensure-RelativePath ($Root, $Target) {
    $RootUri = New-Object System.Uri ("$Root/")
    $TargetUri = New-Object System.Uri ($Target)
    return [System.Uri]::UnescapeDataString($RootUri.MakeRelativeUri($TargetUri).ToString()).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

$SourcePath = (Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop).Path
$DestinationPath = if ([System.IO.Path]::IsPathRooted($DestinationPath)) {
    [System.IO.Path]::GetFullPath($DestinationPath)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path -Path (Get-Location).Path -ChildPath $DestinationPath))
}

# 1. Setup the root temporary path (e.g., C:\temp\{guid})
$GuidStr = (New-Guid).ToString("N")
$BaseTempPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $GuidStr

# Grab the identity name of the top-level directory we are moving (e.g., "a" from "C:\a")
$TopLevelDirName = Split-Path -Path $SourcePath -Leaf

Write-Host "Initialising temporary workspace at: $BaseTempPath" -ForegroundColor Cyan

function Copy-AndConvertRecursive {
    param(
        [string]$CurrentSrc,
        [string]$CurrentTempDst
    )

    # Ensure the current temporary directory layer exists
    if (-not (Test-Path -Path $CurrentTempDst)) {
        New-Item -ItemType Directory -Path $CurrentTempDst | Out-Null
    }

    # Process all files in the current source folder
    $Files = Get-ChildItem -Path $CurrentSrc -File
    foreach ($File in $Files) {
        if ($File.Extension -ieq ".flac" -or $File.Extension -ieq ".wav") {
            Write-Host "Converting audio: $($File.Name)" -ForegroundColor Yellow
            
            # Execute your custom function. 
            # Per your definition: Convert-X <input filename> <output directory>
            $o = Join-Path -Path $CurrentTempDst ($File.BaseName + ".aiff")
            ffmpeg -i $File.FullName -hide_banner -loglevel error -f aiff -acodec pcm_s16le -write_id3v2 1 $o 
        }
        else {
            # For non-audio files, natively copy them straight to the temp branch
            $TempTargetFile = Join-Path -Path $CurrentTempDst -ChildPath $File.Name
            Copy-Item -Path $File.FullName -Destination $TempTargetFile -Force
        }
    }

    # Handle second-layer directories and beyond recursively
    $SubDirectories = Get-ChildItem -Path $CurrentSrc -Directory
    foreach ($SubDir in $SubDirectories) {
        # Construct the next depth layer utilizing the temporary path + sub-directory name
        $NextTempDst = Join-Path -Path $CurrentTempDst -ChildPath $SubDir.Name
        
        # Recurse down
        Copy-AndConvertRecursive -CurrentSrc $SubDir.FullName -CurrentTempDst $NextTempDst
    }
}
# --- END OF INNER FUNCTION ---

try {
    # 2. Kick off the recursion starting at the root temp directory + original top-folder name
    $InitialTempDst = Join-Path -Path $BaseTempPath -ChildPath $TopLevelDirName
    Copy-AndConvertRecursive -CurrentSrc $SourcePath -CurrentTempDst $InitialTempDst

    # 3. Work is finished. Move/Merge from Temp to Final Destination safely.
    Write-Host "Conversion stage complete. Merging files to: $DestinationPath" -ForegroundColor Green
    
    # Discover all items inside the top-level temp structure to merge over
    $TempItemsToMove = Get-ChildItem -Path $InitialTempDst -Recurse

    foreach ($Item in $TempItemsToMove) {
        # Calculate the final home relative to the true target folder
        $RelativePath = Ensure-RelativePath -Root $InitialTempDst -Target $Item.FullName
        $FinalDestinationFile = Join-Path -Path (Join-Path -Path $DestinationPath -ChildPath $TopLevelDirName) -ChildPath $RelativePath

        if ($Item.PSIsContainer) {
            # If it's a directory, safely ensure it exists in C:/y
            if (-not (Test-Path -Path $FinalDestinationFile)) {
                New-Item -ItemType Directory -Path $FinalDestinationFile | Out-Null
            }
        }
        else {
            # Rule: If folder exists, use it, but files must NOT be overwritten
            if (-not (Test-Path -Path $FinalDestinationFile)) {
                $ParentDir = Split-Path -Path $FinalDestinationFile -Parent
                if (-not (Test-Path -Path $ParentDir)) { New-Item -ItemType Directory -Path $ParentDir | Out-Null }
                
                Move-Item -Path $Item.FullName -Destination $FinalDestinationFile
            }
            else {
                Write-Warning "Skipped overwriting existing file at final location: $FinalDestinationFile"
            }
        }
    }
}
finally {
    # 4. Global Cleanup of temporary folder
    if (Test-Path -Path $BaseTempPath) {
        Write-Host "Cleaning up workspace... $BaseTempPath" -ForegroundColor Gray
        Remove-Item -Path $BaseTempPath -Recurse -Force
    }
}


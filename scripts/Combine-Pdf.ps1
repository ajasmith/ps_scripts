# Combine-Pdf.ps1
Param (
    [Parameter(
        Mandatory = $true,
        HelpMessage = "Output filename is required")]
    [string] $Output,

    [Parameter(
        Mandatory = $true,
        ValueFromRemainingArguments = $true,
        Position = 0,
        HelpMessage = "Please provide at least one input file")]
    [string[]] $Inputs
)

function WriteTex {
    param(
        [Parameter(Mandatory=$false)][string]$toWrite = "",
        [Parameter(Mandatory=$true)][string]$File
        )

    #enable this line for debugging latex intermediate file
    #Write-Host $toWrite

    $toWrite | Out-File -FilePath $File -Encoding ASCII -Append
}

function Clear-File{
    param([Parameter(Mandatory=$true)][string] $FileName)
    if (Test-Path $FileName -PathType Leaf) {
        Remove-Item($FileName)
    }
}

function Write-LaTexFile {
    param([string] $FileName, [string[]] $files)

    Clear-File $FileName
    WriteTex "\documentclass{minimal}" -File $FileName
    WriteTex "\usepackage{pdfpages}" -File $FileName
    WriteTex "\begin{document}" -File $FileName
    
    Write-Host "----------------------------------------------"
    Write-Host "Combining files: "

    Foreach ($f in Get-Item($files))
    {
        if ($f.Exists) {
            if ($f.Extension -eq ".pdf"){
                $AbsolutePath = $f -replace '\\','/'
                $Line = "  \includepdf[pages=-]{"+$AbsolutePath+"}"
                Write-Host "  "$AbsolutePath
                WriteTex $Line -File $FileName    
            }
            else {
                Write-Host "  ERROR: "$AbsolutePath" is not a pdf file. Skipping..."
            }
        }
        else {
            Write-Host "  ERROR: no such file. Skipping"
        }
    }

    Write-Host "----------------------------------------------"
    
    WriteTex "\end{document}" -File $filename
}

function Convert-LatexToPdf{
    param([Parameter(Mandatory=$true)][string] $tex)
    pdflatex.exe $tex -quiet -interaction=nonstopmode *> $null
}

# Setup variables for intermediary tex files
$TexFilePath = ".\pdfcombinetmp.tex"
$TempPdfPath = ".\pdfcombinetmp.pdf"
$AuxFilePath = ".\pdfcombinetmp.aux"
$LogFilePath = ".\pdfcombinetmp.log"

# Create the latex file and build
Write-LaTexFile $TexFilePath $Inputs
Convert-LatexToPdf $TexFilePath

# Move temporary pdf to final path
Move-Item -Path $TempPdfPath -Destination $Output -Force
Write-Host $Output "created."

# Remove the latex intermediary files
Remove-Item -Path $TexFilePath
Remove-Item -Path $AuxFilePath
Remove-Item -Path $LogFilePath

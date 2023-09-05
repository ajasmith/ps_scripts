# Extract-PdfPages.ps1
Param (
    [Parameter(
        Mandatory = $true,
        HelpMessage = "Please provide an input file")]
    [string] $InputFileName,

    [Parameter(
        Mandatory = $true,
        HelpMessage = "Example usage: 3,{},8-10,15 will insert page 3, an empty page, and pages 8, 9, 10, and 15.")]
    [string] $Pages,

    [Parameter(
        Mandatory = $true,
        HelpMessage = "Output filename is required")]
    [string] $OutputFileName
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
    param([string] $FileName, [string] $InputFileName, [string] $Pages)

    Clear-File $FileName
    WriteTex "\documentclass{minimal}" -File $FileName
    WriteTex "\usepackage{pdfpages}" -File $FileName
    WriteTex "\begin{document}" -File $FileName
    

    $Item = Get-Item($InputFileName)
    if ($Item.Exists) {
        if ($Item.Extension -eq ".pdf"){
            $AbsolutePath = $Item -replace '\\','/'
            $Line = "  \includepdf[pages={"+$Pages+"}]{"+$AbsolutePath+"}"
            Write-Host "Extracting page(s) $Pages from $AbsolutePath"
            WriteTex $Line -File $FileName    
        }
        else {
            Write-Host "  ERROR: "$AbsolutePath" is not a pdf file. Skipping..."
        }
    }
    else {
        Write-Host "  ERROR: no such file. Skipping"
    }
    
    WriteTex "\end{document}" -File $filename
}

function Convert-LatexToPdf{
    param([Parameter(Mandatory=$true)][string] $tex)
    pdflatex.exe $tex -quiet -interaction=nonstopmode *> $null
}

# Setup variables for intermediary tex files
$TexFilePath = ".\pdfextracttmp.tex"
$TempPdfPath = ".\pdfextracttmp.pdf"
$AuxFilePath = ".\pdfextracttmp.aux"
$LogFilePath = ".\pdfextracttmp.log"

# Create the latex file and build
Write-LaTexFile $TexFilePath $InputFileName $Pages
Convert-LatexToPdf $TexFilePath

# Move temporary pdf to final path
Move-Item -Path $TempPdfPath -Destination $OutputFileName -Force
Write-Host $OutputFileName "created."

# Remove the latex intermediary files
Remove-Item -Path $TexFilePath
Remove-Item -Path $AuxFilePath
Remove-Item -Path $LogFilePath

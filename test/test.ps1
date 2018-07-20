$DirCapture = Join-Path $PSScriptRoot -ChildPath 'capture'

function Get-CapturePath ([string]$Path) {
    # TODO: Consider adding a transform function to match
    Join-Path $DirCapture -ChildPath $Path
}


function Add-File ([string]$Path) {
    New-Item -Path (Get-CapturePath $Path) -ItemType File
}


function Add-Dir ([string]$Path) {
    New-Item -Path (Get-CapturePath $Path) -ItemType Directory
}


Get-CapturePath 'X:\'

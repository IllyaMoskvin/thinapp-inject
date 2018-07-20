$DirCapture = Join-Path $PSScriptRoot -ChildPath 'capture'


function Get-MacroPath ([string]$Path) {

    # Replace drive prefix, uppercase
    @('^([A-Za-z]):\\', '%drive_([A-Za-z])%\\') | ForEach-Object {
        if ($Path -match $_) {
            $drive = [regex]::match($Path, $_).Groups[1].Value
            $drive = $drive.ToUpper()
            $Path = $Path -replace $_, "%drive_$drive%\"
        }
    }

    $Path
}


function Get-CapturePath ([string]$Path) {
    Join-Path $DirCapture -ChildPath (Get-MacroPath $Path)
}


function Add-File ([string]$Path) {
    New-Item -Path (Get-CapturePath $Path) -ItemType File
}


function Add-Dir ([string]$Path) {
    New-Item -Path (Get-CapturePath $Path) -ItemType Directory
}


Get-CapturePath 'x:\'
Get-CapturePath 'X:\'

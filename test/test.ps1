$DirCapture = Join-Path $PSScriptRoot -ChildPath 'capture'
$DirBuild = Join-Path $PSScriptRoot -ChildPath 'build'


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


function Test-IsDirectory ([string]$Path) {
    (Get-Item -Path $Path) -is [System.IO.DirectoryInfo]
}


function Remove-Mock ([string]$Path) {
    $Path = (Get-CapturePath $Path)
    if (!(Test-Item $Path)) {
        Write-Host "$Path does not exist."
        exit 1
    } elseif (Test-IsDirectory $Path) {
        Remove-Item -Recurse -Force -Path $Path
    } else {
        Remove-Item -Path $fpath
    }
}


function Install-Build {
    # Redirecting to Out-Null doesn't suppress `STDERR` output
    & (Join-Path $DirCapture -ChildPath 'build.bat') | Out-Null
}


function Uninstall-Build {
    Remove-Item -Recurse -Force -Path $DirBuild
}


Get-CapturePath 'x:\'
Get-CapturePath 'X:\'

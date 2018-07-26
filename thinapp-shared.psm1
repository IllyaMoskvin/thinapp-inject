# This file contains function required by both `inject` and `test`
# TODO: Figure out how to cleanup these exported functions after script end

# Normalizes path relative to the working directory
function Get-NormalizedPath ([string]$Path) {
    if (![System.IO.Path]::IsPathRooted($Path)) {
        $Path = Join-Path (Get-Location) $Path
    }
    [System.IO.Path]::GetFullPath($Path)
}


# Derive ThinApp directory from params or the environment.
# Mirrors fallback logic in build.bat
function Get-DirBin ([string]$ThinAppPath, [string]$DirSand) {
    $dir = @(
        # Adding if's to prevent function calls with null
        ($(if ($ThinAppPath) { Get-NormalizedPath $ThinAppPath })),
        ($(if ($env:THINSTALL_BIN) { Get-NormalizedPath $env:THINSTALL_BIN })),
        # Assumes that $DirSand is absolute
        ($(if ($DirSand) { [System.IO.Path]::GetFullPath($DirSand + '\..\..') })),
        # ProgramFiles(x86) won't be defined on 32-bit systems
        ($(if (${env:ProgramFiles(x86)}) { ${env:ProgramFiles(x86)} + '\VMware\VMware ThinApp' })),
        ($(if (${env:ProgramFiles}) { ${env:ProgramFiles} + '\VMware\VMware ThinApp' }))
    ) | Where-Object {
        $_ -and (Test-Path $_ -PathType Container) -and (Test-Path ($_ + '\vregtool.exe'))
    } | Select-Object -First 1

    if (!$dir) {
        throw 'Cannot resolve ThinApp directory. Double-check the `ThinAppPath` param.'
    } else {
        Write-Verbose "Using ThinApp install: $dir"
    }

    @( 'vftool.exe', 'vregtool.exe' ) | ForEach-Object {
        if (!(Test-Path "$dir\$_")) {
            throw "Missing $_ in $dir"
        }
    }

    $dir
}

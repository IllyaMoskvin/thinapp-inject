param (
    [Parameter(Mandatory=$true)]
    [string]$SandboxPath,

    # ThinApp version used to capture the app (CapturedUsingVersion)
    [string]$Version,

    # We can attempt to recover if this is omitted
    [string]$ThinAppPath,

    # Don't create Registry.rw.tvr.bak* files
    [switch]$NoBackup,

    # Don't remove the tmp directory (debug)
    [switch]$KeepTemp
)


# Normalizes path relative to the working directory
function Get-NormalizedPath ([string]$Path) {
    if (![System.IO.Path]::IsPathRooted($Path)) {
        $Path = Join-Path (Get-Location) $Path
    }
    [System.IO.Path]::GetFullPath($Path)
}


# Return absolute path to sandbox, ensuring it exists
function Get-DirSand ([string]$SandboxPath) {

    # Resolve relative to working directory
    $dir = Get-NormalizedPath $SandboxPath

    if (!(Test-Path $dir -PathType Container)) {
        throw "SandboxPath does not exist or is not a directory: $dir"
    }

    # Ensure that the registry has been "primed"
    if (!(Test-Path "$dir\Registry.rw.tvr")) {
        throw "Missing Registry.rw.tvr in $dir"
    }

    $dir
}


# Mirrors fallback logic in build.bat
function Get-DirBin ([string]$ThinAppPath) {
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


# https://stackoverflow.com/questions/24992681/powershell-check-if-a-file-is-locked
function Reset-Item ([string]$Path, [switch]$Directory) {
    try {
        if (Test-Path $Path -ErrorAction Stop) {
            if ($Directory) {
                Remove-Item -Path $Path -ErrorAction Stop -Recurse -Force
            } else {
                Remove-Item -Path $Path -ErrorAction Stop
            }
        }
    } catch {
        throw ('Cannot remove item. Ensure it is not in use: ' + $Path)
    }
}


# Required by vftool and vregtool. Otherwise, you'll get this error:
# Missing required parameter CapturedUsingVersion in section [BuildOptions] for [..]\Package.ini
function Get-PackageIniPath {
    @(
        ($DirSand),
        ($DirNew),
        ($DirOld),
        ($DirOut),
        # ListFiles requires one in root..?
        ([System.IO.path]::GetPathRoot($DirRoot))
    ) | ForEach-Object {
        Join-Path $_ -ChildPath 'Package.ini'
    }
}


# Get ThinApp version with which the application was captured from param.
# TODO: Defaulting version generically (5 vs. 5.x.x) seems to work fine. Confirm?
# TODO: Attempt to extract it from the application..? But we don't know its location.
# 54 00 68 00 69 00 6E 00 41 00 70 00 70 00 56 00 65 00 72 00 73 00 69 00 6F 00 6E 00 00 00
# ...then read until the next 00 00
# foobar.exe -thinstallversion
function Get-Version {
    if (!$Version ) {
        $Version = '5'
    }

    Write-Verbose "Setting `CapturedUsingVersion` to $Version"
    $Version
}


function Get-PackageIni {
    @(
        ('[BuildOptions]')
        ('CapturedUsingVersion=' + $Version)
    )
}


# Write *ThinApp-friendly* file. All text files handled by ThinApp:
# Little-endian UTF-16 Unicode text, with CRLF, CR line terminators
function Write-File ([string]$Path, [string[]]$Value) {
    $Value | Out-File -FilePath $Path -Encoding Unicode -Force
}


# Normalize params to our script's conventions
$DirSand = Get-DirSand $SandboxPath
$DirBin = Get-DirBin $ThinAppPath

$Version = Get-Version $Version

# Define some other paths for convenience
$DirRoot = $PSScriptRoot
$DirTemp = Join-Path $DirRoot -ChildPath 'tmp'

$DirNew = Join-Path $DirTemp -ChildPath 'new'
$DirOld = Join-Path $DirTemp -ChildPath 'old'
$DirOut = Join-Path $DirTemp -ChildPath 'out'

# Meant for subprocess calls
$BinVftool = Join-Path $DirBin -ChildPath 'vftool.exe'
$BinVregtool = Join-Path $DirBin -ChildPath 'vregtool.exe'

# Original tvr file in the sandbox
$TvrOriginal = Join-Path $DirSand -ChildPath 'Registry.rw.tvr'

# Base filename for backups, appended with number
$TvrBackupTemplate = Join-Path $DirSand -ChildPath 'Registry.rw.tvr.bak'

# Temporary working files, for output, etc.
$TvrOld = Join-Path $DirTemp -ChildPath 'old.tvr'
$TvrNew = Join-Path $DirTemp -ChildPath 'new.tvr'
$TvrOut = Join-Path $DirTemp -ChildPath 'out.tvr'

# ThinApp's virtual registry key to root of its virtual filesystem
$KeyBase = 'HKEY_LOCAL_MACHINE\FS'

# These will be generated by the vregtool calls, assuming normal $KeyBase
$TxtOld = Join-Path $DirOld -ChildPath 'HKEY_LOCAL_MACHINE.txt'
$TxtNew = Join-Path $DirNew -ChildPath 'HKEY_LOCAL_MACHINE.txt'
$TxtOut = Join-Path $DirOut -ChildPath 'HKEY_LOCAL_MACHINE.txt'


# Reset our temporary directory
Reset-Item $DirTemp -Directory

# Create temporary directories, if they don't exist yet
@(($DirTemp), ($DirNew), ($DirOld), ($DirOut)) | ForEach-Object {
    if (!(Test-Path -PathType Container $_)) {
        New-Item -ItemType Directory -Force -Path $_ | Out-Null
    }
}

# Delete these files to avoid "Corruption detected" errors
# I think these are triggered by .transact specifically
# See `DisableTransactionRegistry` in Package.ini
@(
    (Join-Path $DirSand -ChildPath 'Registry.rw.tvr.lck')
    (Join-Path $DirSand -ChildPath 'Registry.rw.tvr.transact')
    (Join-Path $DirSand -ChildPath 'Registry.tlog')
    (Join-Path $DirSand -ChildPath 'Registry.tlog.cache')
) | ForEach-Object {
    Reset-Item $_
}

# Create Package.ini in directories we'll be processing
Get-PackageIniPath | ForEach-Object {
    Write-File -Path $_ -Value (Get-PackageIni)
}

# Copy the original tvr to tmp/old.tvr
Copy-Item -Path $TvrOriginal -Destination $TvrOld

# Generate a new tvr file, based on current sandbox state
& $BinVftool "$TvrNew" 'ImportDir' "$DirSand"

# Make a copy of the new tvr for modification
Copy-Item -Path $TvrNew -Destination $TvrOut

# Delete the `thinstall` key from the outgoing tvr. This cascades to all subkeys
& $BinVregtool "$TvrOut" 'DelSubkey' "HKEY_LOCAL_MACHINE\FS\%ProgramFilesDir%\ThinstallPlugins" "-NoMark"

# Extract the virtual filesystem keys from all tvr's
& $BinVregtool "$TvrOld" 'ExportTxt' "$DirOld" "$KeyBase"
& $BinVregtool "$TvrNew" 'ExportTxt' "$DirNew" "$KeyBase"
& $BinVregtool "$TvrOut" 'ExportTxt' "$DirOut" "$KeyBase"

# Read the generated HKEY_LOCAL_MACHINE.txt into arrays
# Note that these files are UTF-16 w/ BOM (LE)
$DataOld = Get-Content -Path $TxtOld -ErrorAction Stop
$DataNew = Get-Content -Path $TxtOut -ErrorAction Stop

# TODO: Make this less imperative? Might be over-engineering.
$DataNew = $DataNew | ForEach-Object { $i = 0 } {

    # We reached the start of a new entry, so let's do a look-ahead
    if ($_.StartsWith('isolation_')) {

        # It seems that the 5th byte determines if it's a directory
        for ($j = $i+1; $j -lt $DataNew.Length; $j++) {
            if ($DataNew[$j].StartsWith('  REG_BINARY=')) {
                $isDir = $DataNew[$j][27] -eq '1'
                break
            }
            if ($DataNew[$j].StartsWith('isolation_')) {
                $isDir = $true
                break
            }
        }

        if ($isDir) {
            # Redirects all writes to the sandbox
            $_ = $_ -Replace '^isolation_.+? ', 'isolation_writecopy '
        } else {
            # Doing this for files allows us to override files present inside the packaged filesystem
            $_ = $_ -Replace '^isolation_.+? ', 'isolation_sb_only '
        }

    }

    if ($_.StartsWith('  REG_BINARY=')) {

        # trims everything after col 122 - checksum info?
        $_ = $_.SubString(0,121)

        # replaces #00 w/ #01 - origin is sandbox?
        [char[]]$char = $_
        $char[15] = '1'
        $_ = [string]::new($char)

    }

    $i++

    $_
}

# Remove auto-injected references to ThinstallPlugins
# These are already included in the virtualized application
$i = [array]::IndexOf($DataNew, 'isolation_writecopy HKEY_LOCAL_MACHINE\FS\%ProgramFilesDir%')

if ($i -gt -1) {

    # This only works because we ran `DelSubkey` earlier
    $isLast = ( $DataNew[($i+1)..$DataNew.Length] | Where-Object { $_.StartsWith('isolation') } ).Length -lt 1

    if ($isLast) {

        $DataNew = $DataNew[0..($i-1)]

    } else {

        # If it's not the last item, then something else is in ProgramFiles
        # Remove Value/REG_SZ pairs if they point at 'ThinstallPlugins'

        # Find the next 'isolation' item
        for ($j=($i+1); $j -lt $DataNew.Length; $j++) {
            if ($DataNew[$j].StartsWith('isolation')) {
                break
            }
        }

        # For the parts between $i and $j, build array sans these pairs
        $temp = @()

        for ($k=$i; $k -lt $j; $k++) {
            if ($DataNew[$k].StartsWith('  Value')) {
                if ($DataNew[$k+1] -eq '  REG_SZ=ThinstallPlugins#00') {
                    $k++
                    continue
                }
            }
            $temp += $DataNew[$k]
        }

        # Combine the arrays, using our temp array w/ skips
        $DataNew = $DataNew[0..($i-1)] + $temp + $DataNew[$j..$DataNew.Length]

    }
}

# Go through $DataNew and compare with $DataOld
# Remove lines from that have only "empty" Value/REG_BINARY pairs, but aren't as such in old
$temp = @()
for ($i=0; $i -lt $DataNew.Length; $i++) {
    $temp += $DataNew[$i]
    if ($DataNew[$i].StartsWith('isolation')) {
        $item = $DataNew[$i] -Replace '^isolation_.+ (.+)$', '$1'
        $isInOld = $DataOld | Where-Object { $_.EndsWith($item) }
        if (!($isInOld -eq $null)) {
            $j = [array]::IndexOf($DataOld, $isInOld)
            if ($DataOld[($j+1)].Length -eq 0) {
                if ( $DataNew[($i+2)] -eq ('  REG_BINARY=#01#00#00#00#01' + ('#00' * 31)) ) {
                    $i++
                    $i++
                }
            }
        }
    }
}

$DataNew = $temp

# Ensure there's only two trailing newlines
for ($i = $DataNew.Length; $i -gt 0; $i--) {
    if ($DataNew[$i].Length -lt 1) {
        $DataNew = $DataNew[0..($i-1)]
    } else {
        break
    }
}

$DataNew += ''

# Write the edited data to the outgoing reg file
Write-File -Path $TxtOut -Value $DataNew

# Make a copy of the old tvr for modification
Copy-Item -Path $TvrOld -Destination $TvrOut

# Remove all filesystem data from the old tvr
& $BinVregtool "$TvrOut" 'DelSubkey' "$KeyBase" "-NoMark"

# Import new registry text file into old tvr
& $BinVregtool "$TvrOut" 'ImportDir' "$DirOut"

# Backup the current tvr file
if (!$NoBackup) {
    $i = 0
    do {
        $TvrBackup = $TvrBackupTemplate + $i
        $i++
    } until (!(Test-Path $TvrBackup))

    Copy-Item -Path $TvrOriginal -Destination $TvrBackup
}

# Replace the current tvr file
Copy-Item -Path $TvrOut -Destination $TvrOriginal

# Cleanup all the Package.ini we created...
Get-PackageIniPath | ForEach-Object {
    Remove-Item -Path $_
}

# Reset our temporary directory
if (!$KeepTemp) {
    Reset-Item $DirTemp -Directory
}

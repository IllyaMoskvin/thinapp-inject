param (
    # Path to directory with vregtool.exe and vftool.exe
    [string]$ThinAppPath,

    # Don't delete ..\tmp folder in root
    [switch]$KeepTemp,

    # Compare virtual registry of injected vs. touched through entrypoint
    [switch]$TestRegistry,

    # Save virtual registry text files to test\registry
    [switch]$SaveRegistry,

    # Don't delete the test\build directory
    [switch]$SaveBuild,

    # Synonymous to both SaveRegistry and SaveBuild
    [switch]$Save,

    # Test suite to execute, e.g. 'Full' for Get-FullTest
    [string]$Test
)

Import-Module "$PSScriptRoot\..\thinapp-shared.psm1"

$DirRoot = Get-NormalizedPath (Join-Path $PSScriptRoot -ChildPath '../')
$DirTemp = Join-Path $DirRoot -ChildPath 'tmp'

$DirCapture = Join-Path $PSScriptRoot -ChildPath 'capture'
$DirBuild = Join-Path $PSScriptRoot -ChildPath 'build'
$DirSandbox = Join-Path $DirBuild -ChildPath 'Data'

$DirRegistry = Join-Path $PSScriptRoot -ChildPath 'registry'

$TxtRealRegistry = Join-Path $DirRegistry -ChildPath 'real.txt'
$TxtFakeRegistry = Join-Path $DirRegistry -ChildPath 'fake.txt'

$BinTest = Join-Path $DirBuild -ChildPath 'cmd.exe'
$BinScript = Join-Path $DirRoot -ChildPath 'thinapp-inject.ps1'

$TvrSandbox = Join-Path $DirSandbox -ChildPath 'Registry.rw.tvr'

$DirBin = Get-DirBin $ThinAppPath $DirSandbox

$BinVregtool = Join-Path $DirBin -ChildPath 'vregtool.exe'

# Set the envar required by build.bat and thinapp-inject.ps1
$OldEnvThinstallBin = $env:THINSTALL_BIN
$env:THINSTALL_BIN = $DirBin


$SharedMacros = @{
    '%Fonts%' = 'C:\Windows\Fonts'
    '%Resources Localized%' = ('C:\Windows\Resources\' + (Get-Culture).LCID) # TODO: Confirm?
    '%Resources%' = 'C:\Windows\Resources'
    '%SystemRoot%' = 'C:\Windows'
    '%SystemSystem%' = 'C:\Windows\System32'
    # %Program Files Common% and %ProgramFilesDir% is set manually below
}


# https://pubs.vmware.com/thinapp-5/topic/com.vmware.thinapp50.userguide.doc/processing_systemroot.html
$OldMacros = @{
    '%AdminTools%' = 'C:\Documents and Settings\<user_name>\Start Menu\Programs\Administrative Tools'
    '%AppData%' = 'C:\Documents and Settings\<user_name>\Application Data'
    '%CDBurn Area%' = 'C:\Documents and Settings\<user_name>\Local Settings\Application Data\Microsoft\CD Burning'
    '%Common AdminTools%' = 'C:\Documents and Settings\All Users\Start Menu\Programs\Administrative Tools'
    '%Common AppData%' = 'C:\Documents and Settings\All Users\Application Data'
    '%Common Desktop%' = 'C:\Documents and Settings\All Users\Desktop'
    '%Common Documents%' = 'C:\Documents and Settings\All Users\Documents'
    '%Common Favorites%' = 'C:\Documents and Settings\All Users\Favorites'
    '%Common Programs%' = 'C:\Documents and Settings\All Users\Start Menu\Programs'
    '%Common StartMenu%' = 'C:\Documents and Settings\All Users\Start Menu'
    '%Common Startup%' = 'C:\Documents and Settings\All Users\Start Menu\Programs\Startup'
    '%Common Templates%' = 'C:\Documents and Settings\All Users\Templates'
    '%Cookies%' = 'C:\Documents and Settings\<user_name>\Cookies'
    '%Desktop%' = 'C:\Documents and Settings\<user_name>\Desktop'
    # Drive prefixes omitted, see Get-DrivePrefix
    '%Favorites%' = 'C:\Documents and Settings\<user_name>\Favorites'
    '%History%' = 'C:\Documents and Settings\<user_name>\Local Settings\History'
    '%Internet Cache%' = 'C:\Documents and Settings\<user_name>\Local Settings\Temporary Internet Files'
    '%Local AppData%' = 'C:\Documents and Settings\<user_name>\Local Settings\Application Data'
    '%My Pictures%' = 'C:\Documents and Settings\<user_name>\My Documents\My Pictures'
    '%My Videos%' = 'C:\Documents and Settings\<user_name>\My Documents\My Videos'
    '%NetHood%' = 'C:\Documents and Settings\<user_name>\NetHood'
    '%Personal%' = 'C:\Documents and Settings\<user_name>\My Documents'
    '%PrintHood%' = 'C:\Documents and Settings\<user_name>\PrintHood'
    '%Profile%' = 'C:\Documents and Settings\<user_name>'
    '%Profiles%' = 'C:\Documents and Settings'
    '%Programs%' = 'C:\Documents and Settings\<user_name>\Start Menu\Programs'
    '%Recent%' = 'C:\Documents and Settings\<user_name>\My Recent Documents'
    '%SendTo%' = 'C:\Documents and Settings\<user_name>\SendTo'
    '%Startup%' = 'C:\Documents and Settings\<user_name>\Start Menu\Programs\Startup'
    '%TEMP%' = 'C:\Documents and Settings\<user_name>\Local Settings\Temp'
    '%Templates%' = 'C:\Documents and Settings\<user_name>\Templates'
}


# https://blogs.vmware.com/thinapp/2012/05/macro-folder-locations-and-newer-versions-of-windows.html
$NewMacros = @{
    '%AdminTools%' = 'C:\Users\<user_name>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Administrative Tools'
    '%AppData%' = 'C:\Users\<user_name>\AppData\Roaming'
    '%CDBurn Area%' = 'C:\Users\<user_name>\AppData\Local\Microsoft\Windows\Burn'
    '%Common AdminTools%' = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools'
    '%Common AppData%' = 'C:\ProgramData'
    '%Common Desktop%' = 'C:\Users\Public\Desktop'
    '%Common Documents%' = 'C:\Users\Public\Documents'
    # '%Common Favorites%' = ..?
    '%Common Programs%' = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs'
    '%Common StartMenu%' = 'C:\ProgramData\Microsoft\Windows\Start Menu'
    '%Common Startup%' = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
    '%Common Templates%' = 'C:\ProgramData\Microsoft\Windows\Templates'
    '%Cookies%' = 'C:\Users\<user_name>\AppData\Roaming\Microsoft\Windows\Cookies'
    '%Desktop%' = 'C:\Users\<user_name>\Desktop'
    '%Favorites%' = 'C:\Users\<user_name>\Favorites'
    '%History%' = 'C:\Users\<user_name>\AppData\Local\Microsoft\Windows\History'
    '%Internet Cache%' = 'C:\Users\<user_name>\AppData\Local\Microsoft\Windows\Temporary Internet Files'
    '%Local AppData%' = 'C:\Users\<user_name>\AppData\Local'
    # '%My Pictures%' = ..?
    # '%My Videos%' = ..?
    '%NetHood%' = 'C:\Users\<user_name>\AppData\Roaming\Microsoft\Windows\Network Shortcuts'
    '%Personal%' = 'C:\Users\<user_name>\Documents'
    '%PrintHood%' = 'C:\Users\<user_name>\AppData\Roaming\Microsoft\Windows\Printer Shortcuts'
    '%Profile%' = 'C:\Users\<user_name>'
    '%Profiles%' = 'C:\Users'
    '%Programs%' = 'C:\Users\<user_name>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs'
    '%Recent%' = 'C:\Users\<user_name>\AppData\Roaming\Microsoft\Windows\Recent'
    '%SendTo%' = 'C:\Users\<user_name>\AppData\Roaming\Microsoft\Windows\SendTo'
    '%Startup%' = 'C:\Users\<user_name>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
    # Is %SystemSystem%' ever C:\Windows\SysWOW64?
    '%TEMP%' = 'C:\Users\<user_name>\AppData\Local\Temp'
    '%Templates%' = 'C:\Users\<user_name>\AppData\Roaming\Microsoft\Windows\Templates'
}

# https://stackoverflow.com/questions/7330187/how-to-find-the-windows-version-from-the-powershell-command-line
$Macros = if ([Environment]::OSVersion.Version -ge (new-object 'Version' 6,1)) {
    $SharedMacros + $NewMacros
} else {
    $SharedMacros + $OldMacros
}

# For effeciency, replace <user_name> with the actual username here
# https://stackoverflow.com/questions/5879871/powershell-updating-hash-table-values-in-a-foreach-loop
foreach ($key in $($Macros.Keys)) {
    $Macros[$key] = $Macros[$key].Replace('<user_name>', $env:UserName)
}

# %ProgramFilesDir% is handled conditionally:
# https://communities.vmware.com/thread/471073
#
# Running the application on a...
#   ...64-bit OS resolves the macro to "C:\Program Files (x86)"
#   ...32-bit OS resolves the macro to "C:\Program Files"
#
# It doesn't seem to matter if the application is 32-bit or 64-bit!
if ([Environment]::Is64BitOperatingSystem) {
    $Macros['%Program Files Common%'] = 'C:\Program Files (x86)\Common Files'
    $Macros['%ProgramFilesDir%'] = 'C:\Program Files (x86)'
} else {
    $Macros['%Program Files Common%'] = 'C:\Program Files\Common Files'
    $Macros['%ProgramFilesDir%'] = 'C:\Program Files'
}


# Pattern should contain $1 where the drive letter goes
function Get-DrivePrefix ([string]$Path, [string]$Pattern) {
    @('^([A-Za-z]):\\', '%drive_([A-Za-z])%\\') | ForEach-Object {
        if ($Path -match $_) {
            $drive = [regex]::match($Path, $_).Groups[1].Value
            $drive = $drive.ToUpper()
            $Pattern = $Pattern.Replace('$1', "$drive")
            $Path = $Path -replace $_, $Pattern
        }
    }
    $Path
}


function Get-RealPath ([String]$Path) {

    # Convert drive prefix into real path, uppercase
    $Path = Get-DrivePrefix $Path '$1:\'

    # https://stackoverflow.com/questions/9015138/looping-through-a-hash-or-using-an-array-in-powershell
    foreach ($key in $($Macros.Keys)) {
        if ($Path.StartsWith($key)) {
            $Path = $Path -replace "^$key", $Macros[$key]
            break
        }
    }

    $Path
}


# We won't specify mock files using real paths, but if we did, use $Macros to convert
function Get-MacroPath ([string]$Path) {

    # Replace drive prefix, uppercase
    $Path = Get-DrivePrefix $Path '%drive_$1%\'

    $Path
}


# Execute some path-based command using our cmd entrypoint
function New-Command ([string]$Path, [string]$Command) {
    $Path = Get-RealPath $Path
    $Command = $Command.Replace('$1', "$Path")
    # Write-Host $Command # Uncomment for debug
    & "$BinTest" /C "$Command"
}


# Check if file or directory is recognized by our test app
function Test-ItemExists ([string]$Path) {
    $output = New-Command $Path 'IF EXIST "$1" (ECHO true) ELSE (ECHO false)'
    $output -eq 'true'
}


# Use our cmd entrypoint to create a file
# https://stackoverflow.com/questions/210201/how-to-create-empty-text-file-from-a-batch-file
function Add-VirtualFile ([string]$Path) {
    New-Command $Path 'type NUL > "$1"' | Out-Null
}


# Use our cmd entrypoint to create a direcctory
# MKDIR can create the full directory hierarchy in one command
# If targeting non-existent drive, define it in `VirtualDrives` in Package.ini
function Add-VirtualDir ([string]$Path) {
    New-Command $Path 'mkdir "$1"' | Out-Null
}


function Get-SandboxPath ([string]$Path) {
    Join-Path $DirSandbox -ChildPath (Get-MacroPath $Path)
}


function Add-SandboxFile ([string]$Path) {
    New-Item -Path (Get-SandboxPath $Path) -Force -ItemType File | Out-Null
}


function Add-SandboxDir ([string]$Path) {
    New-Item -Path (Get-SandboxPath $Path) -ItemType Directory | Out-Null
}


# https://stackoverflow.com/questions/24992681/powershell-check-if-a-file-is-locked
function Reset-Directory ([string]$Path) {
    try {
        if (Test-Path $Path -ErrorAction Stop) {
            Remove-Item -Recurse -Force -Path $Path -ErrorAction Stop
        }
    } catch {
        throw ('Cannot reset directory. Ensure its files are not in use: ' + $Path)
    }
}


function Install-Build {
    # Redirecting to Out-Null doesn't suppress `STDERR` output
    & (Join-Path $DirCapture -ChildPath 'build.bat') | Out-Null
}


function Uninstall-Build {
    Reset-Directory $DirBuild
}


# Runs the inject script. Uses THINSTALL_BIN envar.
# Specifying `Version` to match test Package.ini
function Invoke-Injector {
    & $BinScript -SandboxPath "$DirSandbox" -Version '5.2.3-6945559' -KeepTemp:$KeepTemp -Verbose:$Verbose | Out-Null
}


# TODO: Test that the injector works without an existing Registry.rw.tvr
# For now, run the cmd entrypoint once to create the sandbox registry files
# Do this before running Invoke-Injector after a fresh build!
function Initialize-Sandbox {
    & "$BinTest" /C "exit"
}


function Reset-Sandbox {
    Reset-Directory $DirSandbox
    Initialize-Sandbox # TODO: Remove when ready
}


function Get-SandboxRegistry {
    New-Item -Path $DirTemp -ItemType Directory -Force | Out-Null
    & $BinVregtool "$TvrSandbox" 'ExportTxt' "$DirTemp" 'HKEY_LOCAL_MACHINE\FS'
    Get-Content -Path (Join-Path $DirTemp -ChildPath 'HKEY_LOCAL_MACHINE.txt')
}

# Accepts [hashtable[]] or [string[]] or a mix of the two
# If `Type` key is unspecified, assumes that the path is a file
function Test-SandboxItem ([array]$Item, [boolean]$TestRegistry) {

    # Normalize $Item to [hashtable[]] with `Type` keys
    $Item = $Item | ForEach-Object {

        if ($_ -is [string]) {
            $_ = @{ Path = $_ }
        }

        if ($_ -is [hashtable]) {

            if (!($_.ContainsKey('Path'))) {
                Throw 'Missing `Path` key in test path.'
            }

            # Default to creating files
            if (!($_.ContainsKey('Type'))) {
                $_.Type = 'File'
            } elseif (!(@('Dir', 'File').Contains($_.Type))) {
                Throw ('Invalid `Type` value in test path: ' + [string]$_.Type)
            }

        } else {
            Throw ('Unexpected data type passed to Test-SandboxItem: ' + [string]$_)
        }

        $_
    }

    if ($Save -or $SaveRegistry -or $TestRegistry) {
        Reset-Sandbox

        $Item | ForEach-Object {
            Invoke-Expression ('Add-Virtual' + $_.Type + ' "' + $_.Path + '"')
        }

        $RealRegistry = Get-SandboxRegistry
    }

    Reset-Sandbox

    $Item | ForEach-Object {
        Invoke-Expression ('Add-Sandbox' + $_.Type + ' "' + $_.Path + '"')
    }

    Invoke-Injector

    $Item | ForEach-Object {
        $_.Pass = Test-ItemExists $_.Path
    }

    $Result = @{ Items = $Item }

    if ($Save -or $SaveRegistry -or $TestRegistry) {
        $FakeRegistry = Get-SandboxRegistry
    }

    if ($TestRegistry) {
        $Result.Match = $RealRegistry.Equals($FakeRegistry)
    }

    # Save registry if the param was passed to script
    if ($Save -or $SaveRegistry) {
        if (!(Test-Path $DirRegistry)) {
            New-Item -Path $DirRegistry -ItemType Directory | Out-Null
        }
        $RealRegistry | Out-File -FilePath $TxtRealRegistry -Encoding Unicode -Force
        $FakeRegistry | Out-File -FilePath $TxtFakeRegistry -Encoding Unicode -Force
    }

    $Result
}


function Get-SharedTest {
    @(
        @{
            # Test basic file
            Path = 'X:\foobar.txt'
            Type = 'File'
        }
        @{
            # Test subdirectory
            Path = 'X:\foobar'
            Type = 'Dir'
        }
        @{
            # Test file in subdirectory
            Path = 'X:\foobar\baz.txt'
            Type = 'File'
        }
        @{
            # Test sub-subdirectory
            Path = 'X:\foobar\foobaz'
            Type = 'Dir'
        }
        @{
            # Test sub-sub-sub-directory
            Path = 'X:\foo\bar\baz'
            Type = 'Dir'
        }
    )
}


function Get-BasicTest {
    (Get-SharedTest) + @(
        @{
            # Test something in %SystemSystem%
            # Litmus test for 32-bit vs 64-bit
            Path = '%SystemSystem%\foobar.txt'
            Type = 'File'
        }
        @{
            # Test something in %ProgramFilesDir%
            # This is where ThinstallPlugins live
            Path = '%ProgramFilesDir%\foobar.txt'
            Type = 'File'
        }
        @{
            # Test something in %AppData%
            # Litmus test for macro resolution
            Path = '%AppData%\foobar.txt'
            Type = 'File'
        }
        # TODO: Test extensionless file w/ the same name as a directory?
        # Nevermind, Windows doesn't support that behavior...
    )
}


function Get-MacroTest {
    $Macros.Keys | ForEach-Object {
        @{
            Path = ($_ + '\foobar.txt')
            Type = 'File'
        }
    }
}


# Currently, everything in basic is covered in macro
function Get-FullTest {
    (Get-SharedTest) + (Get-MacroTest)
}


# https://stackoverflow.com/questions/3919798/how-to-check-if-a-cmdlet-exists-in-powershell-at-runtime-via-script
function Test-Command($cmdname)
{
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}


# Cleanup anything left over from previous runs
Uninstall-Build

# We only need to initialize the build once per test run
Install-Build

if (!$Test) {
    Write-Host 'No `Test` param specified. Falling back to `Basic`...'
    $Test = 'Basic'
} elseif (!(Test-Command "Get-${Test}Test")) {
    Write-Host 'Invalid value for `Test` param. Falling back to `Basic`...'
    $Test = 'Basic'
}

Write-Host ('Running `' + $Test + '` test suite...') -ForegroundColor Yellow

$Result = Test-SandboxItem -TestRegistry $TestRegistry -Item (Invoke-Expression "Get-${Test}Test")

$Result.Items | ForEach-Object {
    $checkmark = '[' + $(if ($_.Pass) { 'X' } else { ' ' }) + ']'
    $forecolor = if ($_.Pass) { 'Green' } else { 'Red' }
    $type = $_.Type.PadRight(4, ' ')
    $path = $_.Path
    Write-Host -Object " $checkmark $type $path " -ForegroundColor $forecolor
}

$Passed = $Result.Items | Where-Object { $_.Pass }

Write-Host $Passed.Count 'of' $Result.Items.Count 'tests passed!' -ForegroundColor Yellow

# For now, we'll ignore differences in virtual registry
if ($Result.ContainsKey('Match')) {
    $forecolor = if ($Result.Match) { 'Green' } else { 'Red' }
    Write-Host 'Registry match:' $Result.Match -ForegroundColor $forecolor
}

# Perform cleanup...
if (!($Save -or $SaveRegistry)) {
    Reset-Directory $DirRegistry
}

if (!($Save -or $SaveBuild)) {
    Uninstall-Build
}

$env:THINSTALL_BIN = $OldEnvThinstallBin

# Ensure that creating a file via injection results in...
#   ...the entry point seeing the file
#   ...the same registry output as creating a file via the entrypoint
# Ditto for directories
# Do this for at least one drive
# Do this for each of the hash entrypoints
# Then, do the same by creating a file in a subdirectory of each of the hash entrypoints

$DirCapture = Join-Path $PSScriptRoot -ChildPath 'capture'
$DirBuild = Join-Path $PSScriptRoot -ChildPath 'build'
$DirSandbox = Join-Path $DirBuild -ChildPath 'Data'
$DirRoot = Join-Path $PSScriptRoot -ChildPath '../'

$BinTest = Join-Path $DirBuild -ChildPath 'Test.exe'
$BinScript = Join-Path $DirRoot -ChildPath 'thinapp-inject.ps1'

# https://pubs.vmware.com/thinapp-5/topic/com.vmware.thinapp50.userguide.doc/processing_systemroot.html
$Macros = @{
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
    '%Fonts%' = 'C:\Windows\Fonts'
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
    '%Program Files Common%' = 'C:\Program Files\Common Files'
    '%ProgramFilesDir%' = 'C:\Program Files'
    '%Programs%' = 'C:\Documents and Settings\<user_name>\Start Menu\Programs'
    '%Recent%' = 'C:\Documents and Settings\<user_name>\My Recent Documents'
    '%Resources%' = 'C:\Windows\Resources'
    '%Resources Localized%' = ('C:\Windows\Resources\' + (Get-Culture).LCID) # TODO: Confirm?
    '%SendTo%' = 'C:\Documents and Settings\<user_name>\SendTo'
    '%Startup%' = 'C:\Documents and Settings\<user_name>\Start Menu\Programs\Startup'
    '%SystemRoot%' = 'C:\Windows'
    '%SystemSystem%' = 'C:\Windows\System32'
    '%TEMP%' = 'C:\Documents and Settings\<user_name>\Local Settings\Temp'
    '%Templates%' = 'C:\Documents and Settings\<user_name>\Templates'
}

# For effeciency, replace <user_name> with the actual username here
# https://stackoverflow.com/questions/5879871/powershell-updating-hash-table-values-in-a-foreach-loop
foreach ($key in $($Macros.Keys)) {
    $Macros[$key] = $Macros[$key].Replace('<user_name>', $env:UserName)
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


function Install-Build {
    # Redirecting to Out-Null doesn't suppress `STDERR` output
    & (Join-Path $DirCapture -ChildPath 'build.bat') | Out-Null
}


# TODO: Check if file is locked?
# TODO: Check if file exists..?
# TODO: Improve directory recursion?
function Uninstall-Build {
    Get-ChildItem $DirBuild -Recurse | Remove-Item -Recurse -Force
    Remove-Item -Recurse -Force -Path $DirBuild
}


# Runs the inject script
function Invoke-Injector {
    & $BinScript | Out-Null
}


# TODO: Test that the injector works without an existing Registry.rw.tvr
# For now, run the cmd entrypoint once to create the sandbox registry files
# Do this before running Invoke-Injector after a fresh build!
function Initialize-Sandbox {
    & "$BinTest" /C "exit"
}


# TODO: See Uninstall-Build
function Reset-Sandbox {
    Get-ChildItem $DirSandbox -Recurse | Remove-Item -Recurse -Force
    Remove-Item -Recurse -Force -Path $DirSandbox
    Initialize-Sandbox # TODO: Remove when ready
}


Uninstall-Build
Install-Build

Reset-Sandbox

Add-SandboxDir 'X:\foo\bar\baz\bleh'
Invoke-Injector

Test-ItemExists '%drive_X%\foo\bar\baz'

# This command fails, but the test passes
# The directory already exists - it was injected!
Add-VirtualDir 'X:\foo\bar\baz'
Test-ItemExists '%drive_X%\foo\bar\baz'

Add-VirtualFile '%drive_X%\bar.txt'
Test-ItemExists '%drive_X%\bar.txt'
Test-ItemExists '%drive_X%\lorem.txt'


# Ensure that creating a file via injection results in...
#   ...the same registry output as creating a file via the entrypoint
#   ...the entry point seeing the file
# Ditto for directories
# Do this for each of the hash entrypoints
# Do this for at least one drive
# Then, do the same by creating a file in a subdirectory of each of the hash entrypoints

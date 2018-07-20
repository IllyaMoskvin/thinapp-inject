$DirCapture = Join-Path $PSScriptRoot -ChildPath 'capture'
$DirBuild = Join-Path $PSScriptRoot -ChildPath 'build'

$BinTest = Join-Path $DirBuild -ChildPath 'Test.exe'


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


# https://pubs.vmware.com/thinapp-5/topic/com.vmware.thinapp50.userguide.doc/processing_systemroot.html
function Get-RealPath ([String]$Path) {

    # Convert drive prefix into real path, uppercase
    $Path = Get-DrivePrefix $Path '$1:\'

    # Copied from the link above
    $hash = @{
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
        # Drive prefixes omitted, since we already handled it
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

    # https://stackoverflow.com/questions/9015138/looping-through-a-hash-or-using-an-array-in-powershell
    foreach ($h in $hash.GetEnumerator()) {

        # Normalize the value
        $key = $h.Name
        $val = $h.Value.Replace('<user_name>', $env:UserName)

        if ($Path.StartsWith($key)) {
            $Path = $Path -replace "^$key", $val
            break
        }
    }

    $Path
}


function Get-MacroPath ([string]$Path) {

    # Replace drive prefix, uppercase
    $Path = Get-DrivePrefix $Path '%drive_$1%\'

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


# Check if file is recognized by our test app
function Test-FileExists ([string]$Path) {
    $Path = Get-RealPath $Path
    $command = 'IF EXIST "' + $Path + '" (ECHO true) ELSE (ECHO false)'
    $output = & "$BinTest" /C "$command"
    $output -eq 'true'
}


Get-CapturePath 'x:\'
Get-CapturePath 'X:\'

Get-RealPath '%drive_x%\foo.txt'
Get-RealPath '%drive_X%\bar.txt'
Get-RealPath '%AppData%\baz.txt'

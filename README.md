# thinapp-injector

From [ThinApp 5.1 Package.ini Parameters Reference Guide](https://www.vmware.com/pdf/thinapp51_packageini_reference.pdf#page=85) p. 85, "Making Changes to the Sandbox":

> VMware does not support modifying or adding files directly to the sandbox. If you copy files to the sandbox directory, the files are not visible to the application.

Well, this script allows you to do just that – using ThinApp's default commandline tools!

It works by treating the virtual filesystem _as_ a virtual registry. By performing a series of imports, exports, and overwrites, we can add files that were manually placed in the sandbox directory tree to the `Registry.rw.tvr` of that sandbox.



## Usage

Developed using Windows 7 SP1 (64-bit), ThinApp 5.2.3, and PowerShell 5.0. Untested on other environments.

1. Run your application once to create the sandbox. Exit it.
2. Manually add files and folders to the sandbox. Use folder macros.
3. Run `thinapp-inject.ps1` as described below.

```
.\thinapp-inject.ps1
    -SandboxPath  = Path to your sandbox directory
    -Version      = ThinApp version used to capture the app
    -ThinAppPath  = Path to your ThinApp install directory
    -NoBackup     = Don't create Registry.rw.tvr.bak* files
    -KeepTemp     = Don't delete the `tmp` folder (debug)
```

Relative paths are resolved against the current working directory.

| Param | Type | Description |
| --- | --- | ---|
| `SandboxPath` | `[string]` | **Required.** Path to your sandbox directory for scanning. Must contain `Registry.rw.tvr` |
| `Version` | `[string]` | (Default: `5`) ThinApp version used to capture the application. Used to populate a [CapturedUsingVersion](https://www.vmware.com/pdf/thinapp51_packageini_reference.pdf#page=51) param in a stub `Package.ini`, which ThinApp's tools require to run. |
| `ThinAppPath` | `[string]` | Path to ThinApp's install directory. Must contain `vregtool.exe` and `vftool.exe`. If omitted, it'll attempt some fallbacks, following the logic outlined in `build.bat` files created on every capture. |
| `NoBackup` | `[switch]` | By default, this script will backup your existing `Registry.rw.tvr` to `Registry.rw.tvr*`, where `*` is an incrementing number. Passing this switch will disable that behavior. Previously created `bak` files will not be removed. |
| `KeepTemp` | `[switch]` | This script will create a `tmp` directory wherever it is located while running. Pass this switch to prevent its deletion after the script finishes. Useful for debugging. |

If you don't know what ThinApp version was used to capture your application, run this:

```
.\MyApp.exe -thinstallversion
```
It should show a messagebox with e.g. `5.2.3-694559`. You can specify that as the `Version` directly. There should be no need to truncate it to e.g. `5`. The default targets a major version to maximize compatibility.

There is a [test suite](test\test.ps1) included with the script. It's meant for human consumption, not for CI, but check it out if you are interested in learning more ThinApp techniques. To run all tests:

```powershell
.\test\test.ps1 -ThinAppPath "C:\Path\To\ThinApp" -Test "Full"
```

To illustrate how the `inject` script is used, here's how you might target the test application:

```powershell
# Generate `build`, populate sandbox, but don't run the injector
# All the tests will fail, but this is expected
.\test\test.ps1 -NoInject -SaveBuild -ThinAppPath "C:\Path\To\ThinApp"

# Using a relative SandboxPath example here
.\thinapp-inject.ps1 -SandboxPath ".\test\build\Data" -ThinAppPath "C:\Path\To\ThinApp" -Verbose
```



## Scenario

I'd like to take a moment to discuss scenarios in which this script is most useful, and contrast it against alternative techniques. To ground this pseudo-tutorial, consider the following hypothetical example:

> You are attempting to make a game portable, so that you can play it from a USB drive on different computers.

This script is intended for applications which use the `WriteCopy` [DirectoryIsolationMode](https://www.vmware.com/pdf/thinapp51_packageini_reference.pdf#page=17). In this mode, virtualized applications cannot modify files on the physical file system: ThinApp intercepts write operations and redirects them to the sandbox.

```ini
[Isolation]
DirectoryIsolationMode=WriteCopy
```

For our example, `WriteCopy` is useful if you'd like to keep the save files on the USB drive alongside your game. If you were to use `Merged` isolation mode, your game would write its saves to whatever computer you are using at the time. Obviously, this hinders portability.

Now, with something like save files or settings, such files are created _by_ your virtualized application during normal operation. ThinApp intercepts these write calls, and thus remains aware of filesystem changes by tracking them in the sandbox registry.

But what if you'd like to have the ability to install modifications to your game? In many cases, installing mods involves extracting files from archives and placing them manually somewhere where the game would know to look for them.

Theoretically, if you are using any isolation mode except `Full`, you can recreate the expected directory tree on the physical system, and put the mods there. Your game should be able to detect them.

However, with this method, you once again run into the issue of portability, and in this case, of priority: the virtual application will prioritize any files bundled with it during capture over those on the host system, so if your mod involves overwriting any files bundled with your game, this method is a no-go.

By putting the modded files in the sandbox, you would solve both of these issues. The virtual app prioritizes files in the sandbox over those bundled with it at build-time. From [RegistryIsolationMode](https://www.vmware.com/pdf/thinapp51_packageini_reference.pdf#page=18) docs:

> All runtime modifications to virtual files in the captured application are stored in the sandbox, regardless of the isolation mode setting. At runtime, virtual and physical registry files are indistinguishable to an application, but virtual registry files always supersede physical registry files when both exist in the same location.

Normally, you _cannot_ place files manually in the sandbox. Well, you can, but ThinApp will not recognize them, because they weren't created by the virtual application, and thus are not tracked by its virtual registry.

One method to work around that is to create an entrypoint which allows you to copy files into an application, e.g. `cmd.exe`. However, this may require rebuilding the application, which may not be possible in some scenarios.

That's where this script comes in handy. Whenever you need to manually add files to an existing application, or modify files that haven't been exposed in the sandbox due to write operations through normal interaction, you can use this script to ensure that the application sees your changes.

So when is this script a bad fit for your workflow? I'd say, whenever your application requires you to use the `Merged` isolation mode exclusively. For example, if your application's purpose is to create documents that are meant to be saved to the physical filesystem, you may find it of little use. Though, even then, sandbox injection may prove to be a useful technique, e.g. for installing plugins in a virtualized instance of software such as Photoshop.



## Limitations

You must have an existing sandbox directory before running this script.

If your application uses the [RemoveSandboxOnExit](https://www.vmware.com/pdf/thinapp51_packageini_reference.pdf#page=74) parameter, this script won't work out-of-the-box. You cannot execute it while the application is running, since the files it needs to modify are already in use.

Network sandbox paths are untested. Generally, this script was developed for scenarios where the sandbox is stored in the same directory as the application, though other sandbox paths on the same computer should work fine.

It's unclear if ThinApp resolves the `%ProgramFilesDir%`, `%Program Files Common%`, and `%SystemSystem%` macros differently for 64-bit vs. 32-bit programs and operating systems. This complicated testing, so I cannot say for sure if these paths will work correctly in all cases when injected.

This tool is a generalized, one-off experiment. I do not use ThinApp for my current projects, and I don't intend to do much further work on this codebase. Feel free to submit bug reports or feature requests via [GitHub's issues](https://github.com/IllyaMoskvin/thinapp-inject/issues), but it may take me some time to address them.



## License

This codebase is released under the [MIT License](License.txt). My intent in releasing this tool is to contribute to ThinApp's ecosystem and give back to its community. I had fun writing it, and I hope someone finds it useful, but run it at your own risk!

ThinApp is copyrighted by [VMware](https://www.vmware.com/products/thinapp.html). IANAL, but I do not think this tool constitutes a [derivative work](https://www.rosenlaw.com/lj19.htm), since it merely automates calls to documented tools shipped with ThinApp. However, if you are a VMware representative, and you'd like this repository removed from GitHub, please [contact me](mailto:ivmoskvin@gmail.com), and I'd be happy to do so.



## References

* [ThinApp 5.1 Package.ini Parameters Reference Guide](https://www.vmware.com/pdf/thinapp51_packageini_reference.pdf#page=85)
* [ThinApp Virtual Registry](http://web.archive.org/web/20140124151322/https://www.vmware.com/pdf/thinapp_virt_registry.pdf) (essential)
* [vmware/thinapp_factory – registry.py](https://github.com/vmware/thinapp_factory/blob/master/converter/converter/lib/registry.py)
* [mufana/mufana.github.io – 2017-08-29-Thinapp-and-PowerShell.md](https://github.com/mufana/mufana.github.io/blob/master/_posts/2017-08-29-Thinapp-and-PowerShell.md)
* [VMware Doc Center – ThinApp Folder Macros](https://pubs.vmware.com/thinapp-5/topic/com.vmware.thinapp50.userguide.doc/processing_systemroot.html)
* [VMware ThinApp Blog – Macro folder locations and newer versions of Windows](https://blogs.vmware.com/thinapp/2012/05/macro-folder-locations-and-newer-versions-of-windows.html)

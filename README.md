# thinapp-injector

From [ThinApp 5.1 Package.ini Parameters Reference Guide](https://www.vmware.com/pdf/thinapp51_packageini_reference.pdf#page=85) p. 85, "Making Changes to the Sandbox":

> VMware does not support modifying or adding files directly to the sandbox. If you copy files to the sandbox directory, the files are not visible to the application.

Well, this script allows you to do just that.



## Usage

Developed using Windows 7 SP1 (64-bit), ThinApp 5.2.3, and PowerShell 5.0. Untested on other environments.

```powershell
.\thinapp-inject.ps1
```



## Limitations

It's unclear if ThinApp resolves the `%ProgramFilesDir%`, `%Program Files Common%`, and `%SystemSystem%` macros differently for 64-bit vs. 32-bit programs and operating systems. This complicated testing, so I cannot say for sure if these paths will work correctly in all cases when injected.

This tool is a generalized, one-off experiment. I do not use ThinApp for my current projects, and I do not intend to do further work on this codebase. Feel free to submit bug reports or feature requests via [GitHub's issues](https://github.com/IllyaMoskvin/thinapp-inject/issues), but it may take me some time to address them.



## License

This codebase is released under the [MIT License](License.txt). ThinApp is copyrighted by VMware. My intent in releasing this tool is to contribute to its ecosystem and give back to its community. IANAL, but I do not think it constitutes a [derivative work](https://www.rosenlaw.com/lj19.htm), since all it does is automate calls to documented tools shipped with ThinApp. However, if you are a VMware representative, and you'd like this repository removed from GitHub, please [contact me](mailto:ivmoskvin@gmail.com), and I'd be happy to do so.



## References

* [ThinApp 5.1 Package.ini Parameters Reference Guide](https://www.vmware.com/pdf/thinapp51_packageini_reference.pdf#page=85)
* [ThinApp Virtual Registry](http://web.archive.org/web/20140124151322/https://www.vmware.com/pdf/thinapp_virt_registry.pdf)
* [Messing with a ThinApp's Registry for Fun and Profit!](https://virtuallyjason.blogspot.com/2012/04/messing-with-thinapps-registry-for-fun.html)

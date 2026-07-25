# PATH update design

---

A00 Problem

---

A user PATH can be stored as `REG_EXPAND_SZ` and contain references such as `%USERPROFILE%` or `%LOCALAPPDATA%`. Reading that registry value through an API that expands variables and writing the expanded text back destroys the original representation, can make the value much longer, and can make later manual editing less practical.

---

B00 Implemented approach

---

`add-to-path.ps1` and `install.ps1` open `HKCU\Environment`, read `Path` with `RegistryValueOptions.DoNotExpandEnvironmentNames`, record the existing `RegistryValueKind`, append only a missing launcher entry, and write the new value using the same kind. When no prior value exists, they use `ExpandString`. The shared function verifies the raw value and type after writing.

The scripts update only the current user's PATH and ask first. They add only the repository root for `ed.cmd`; versioned runtime directories are intentionally excluded.

---

C00 Process behavior

---

Windows processes receive an environment block from their parent. The script broadcasts an environment-change message after writing the registry, but the terminal running the installer cannot retroactively change its parent's environment. Open a new terminal before testing the commands.

---

D00 Manual alternative

---

Decline the prompt and add these two entries with the Windows Environment Variables user interface:

```text
<repository root>
```

The exact portable `bin` directory is private launcher state recorded relative to `runtime/` in `runtime/current-bin.txt`.

---

E00 References

---

Microsoft documents `RegistryValueOptions.DoNotExpandEnvironmentNames` as retrieving an expandable registry string without expanding embedded variables:

https://learn.microsoft.com/en-us/dotnet/api/microsoft.win32.registryvalueoptions

Microsoft documents `RegistryValueKind.ExpandString` as the registry type that contains unexpanded environment-variable references:

https://learn.microsoft.com/en-us/dotnet/api/microsoft.win32.registryvaluekind

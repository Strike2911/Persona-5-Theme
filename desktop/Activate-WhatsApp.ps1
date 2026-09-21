param([int]$Port = 0)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
[ComImport, Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C")]
public class ApplicationActivationManager {}
[ComImport, Guid("2E941141-7F97-4756-BA1D-9DECDE894A3D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IApplicationActivationManager {
    [PreserveSig] int ActivateApplication([MarshalAs(UnmanagedType.LPWStr)] string id,
        [MarshalAs(UnmanagedType.LPWStr)] string arguments, uint options, out uint processId);
    [PreserveSig] int ActivateForFile(IntPtr a, IntPtr b, IntPtr c, out uint pid);
    [PreserveSig] int ActivateForProtocol(IntPtr a, IntPtr b, out uint pid);
}
public static class WhatsAppActivation {
    public static uint Open(string id, string args) {
        var manager = (IApplicationActivationManager)new ApplicationActivationManager();
        uint pid;
        int result = manager.ActivateApplication(id, args, 0, out pid);
        Marshal.ThrowExceptionForHR(result);
        Marshal.ReleaseComObject(manager);
        return pid;
    }
}
'@
$package = Get-AppxPackage 5319275A.WhatsAppDesktop
if (!$package) { throw 'No se encontro WhatsApp de Microsoft Store.' }
$arguments = if ($Port -gt 0) { '--edge-webview-switches="--remote-debugging-address=127.0.0.1 --remote-debugging-port=' + $Port + '"' } else { '' }
$processId = [WhatsAppActivation]::Open(($package.PackageFamilyName + '!App'), $arguments)
@{pid=$processId;port=$Port;version=$package.Version} | ConvertTo-Json -Compress

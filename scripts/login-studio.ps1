# Writes the agent account's sign-in into Windows Credential Manager the way Studio stores it (UTF-8 blobs).
param([string]$Cookie, [string]$UserId)
Add-Type @'
using System; using System.Runtime.InteropServices; using System.Text;
public class Cred {
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct CREDENTIAL { public int Flags; public int Type; public string TargetName; public string Comment; public long LastWritten; public int CredentialBlobSize; public IntPtr CredentialBlob; public int Persist; public int AttributeCount; public IntPtr Attributes; public string TargetAlias; public string UserName; }
 [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool CredWrite(ref CREDENTIAL c, int flags);
 public static bool Write(string target, string value) {
  byte[] b = Encoding.UTF8.GetBytes(value); var c = new CREDENTIAL(); c.Type = 1; c.TargetName = target; c.Persist = 2;
  c.CredentialBlobSize = b.Length; c.CredentialBlob = Marshal.AllocHGlobal(b.Length); Marshal.Copy(b, 0, c.CredentialBlob, b.Length);
  bool ok = CredWrite(ref c, 0); Marshal.FreeHGlobal(c.CredentialBlob); return ok; }
}
'@
$base = 'https://www.roblox.com:RobloxStudioAuth'
$ok = [Cred]::Write("${base}Cookies", '.ROBLOSECURITY;') -and [Cred]::Write("${base}userid", $UserId) -and [Cred]::Write("${base}.ROBLOSECURITY$UserId", $Cookie)
"credentials written: $ok"

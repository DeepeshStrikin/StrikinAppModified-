# Flutter APK Build Script - Frees memory before building
Write-Host "Freeing memory before build..." -ForegroundColor Cyan

# Kill known memory hogs that are safe to close
$toKill = @("Discord", "Notion", "AnyDesk", "Wispr Flow", "msedge", "msedgewebview2", "WisprFlow", "dart", "java")
foreach ($proc in $toKill) {
    Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
    Write-Host "  Stopped: $proc" -ForegroundColor Gray
}

# Force garbage collection in Windows
[System.GC]::Collect()

# Clear standby memory via RAMMap equivalent (empty working sets)
$code = @"
using System;
using System.Runtime.InteropServices;
public class MemClear {
    [DllImport("psapi.dll")] public static extern bool EmptyWorkingSet(IntPtr hProcess);
    public static void ClearAll() {
        foreach (var p in System.Diagnostics.Process.GetProcesses()) {
            try { EmptyWorkingSet(p.Handle); } catch {}
        }
    }
}
"@
Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
try { [MemClear]::ClearAll() } catch {}

Start-Sleep -Seconds 2

$free = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB
Write-Host "Free RAM after cleanup: $([math]::Round($free, 1)) GB" -ForegroundColor Green

if ($free -lt 0.8) {
    Write-Host "WARNING: Still low on RAM ($([math]::Round($free,1)) GB free). Close more apps manually." -ForegroundColor Yellow
}

Write-Host "Starting Flutter build..." -ForegroundColor Cyan
Set-Location $PSScriptRoot
flutter clean
flutter pub get
flutter build apk --debug

Write-Host "Build complete." -ForegroundColor Green

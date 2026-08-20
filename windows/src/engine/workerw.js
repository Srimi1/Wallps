/**
 * Win32 WorkerW Desktop Attachment Integration
 * 
 * Attaches a frameless, transparent video window directly to the Windows WorkerW window
 * behind the desktop icons (SHELLDLL_DefView), replicating the exact native desktop wallpaper
 * level on Windows 10 and Windows 11.
 */

const { exec } = require('child_process');

class WindowsWallpaperEngine {
  constructor() {
    this.currentProcess = null;
    this.currentWallpaper = null;
    this.isPaused = false;
  }

  /**
   * Spawns WorkerW behind desktop icons using Progman message 0x052C
   */
  spawnWorkerW() {
    const psScript = `
      $user32 = Add-Type -MemberDefinition @"
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
"@ -Name "Win32Progman" -Namespace "Wallps" -PassThru

      $progman = $user32::FindWindow("Progman", $null)
      $result = [IntPtr]::Zero
      $user32::SendMessageTimeout($progman, 0x052C, [IntPtr]::Zero, [IntPtr]::Zero, 0, 1000, [ref]$result)
    `;

    return new Promise((resolve) => {
      exec(`powershell -NoProfile -ExecutionPolicy Bypass -Command "${psScript.replace(/\n/g, ' ')}"`, (err) => {
        if (err) console.warn('[Wallps Windows Engine] WorkerW initialization note:', err.message);
        resolve();
      });
    });
  }

  /**
   * Sets the wallpaper window as a child of the desktop WorkerW
   */
  async attachToDesktop(windowHwnd) {
    if (process.platform !== 'win32') return;
    await this.spawnWorkerW();

    const psAttach = `
      $user32 = Add-Type -MemberDefinition @"
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr FindWindowEx(IntPtr parentHandle, IntPtr childAfter, string className, string windowTitle);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
"@ -Name "Win32Attach" -Namespace "Wallps" -PassThru

      # Locate the WorkerW behind desktop icons
      $workerW = [IntPtr]::Zero
      $user32::EnumWindows({
        param($topHandle, $lparam)
        $shellView = [Wallps.Win32Attach]::FindWindowEx($topHandle, [IntPtr]::Zero, "SHELLDLL_DefView", $null)
        if ($shellView -ne [IntPtr]::Zero) {
          $script:workerW = [Wallps.Win32Attach]::FindWindowEx([IntPtr]::Zero, $topHandle, "WorkerW", $null)
        }
        return $true
      }, [IntPtr]::Zero)

      if ($workerW -ne [IntPtr]::Zero) {
        $user32::SetParent([IntPtr]${windowHwnd}, $workerW)
      }
    `;

    exec(`powershell -NoProfile -ExecutionPolicy Bypass -Command "${psAttach.replace(/\n/g, ' ')}"`, (err) => {
      if (err) console.warn('[Wallps Windows Engine] Desktop attachment:', err.message);
    });
  }
}

module.exports = new WindowsWallpaperEngine();

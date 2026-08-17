Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$appName = "Risk management"
$bundlePath = Join-Path $PSScriptRoot "rwa_calculator_bundle.zip"
$installRoot = Join-Path $env:LOCALAPPDATA "Programs"
$installDir = Join-Path $installRoot $appName
$stagingDir = Join-Path $env:TEMP ("rwa_calculator_install_" + [guid]::NewGuid().ToString("N"))
$desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "$appName.lnk"
$startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
$startMenuShortcutPath = Join-Path $startMenuDir "$appName.lnk"

if (-not (Test-Path $bundlePath)) {
    throw "Archive introuvable: $bundlePath"
}

if (Get-Process -Name "rwa_calculator" -ErrorAction SilentlyContinue) {
    throw "Fermez Risk management avant de relancer l'installation."
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

try {
    Expand-Archive -Path $bundlePath -DestinationPath $stagingDir -Force

    if (Test-Path $installDir) {
        Remove-Item $installDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Copy-Item (Join-Path $stagingDir "*") $installDir -Recurse -Force

    $exePath = Join-Path $installDir "rwa_calculator.exe"
    if (-not (Test-Path $exePath)) {
        throw "Exécutable principal introuvable après installation: $exePath"
    }

    $shell = New-Object -ComObject WScript.Shell
    foreach ($shortcutPath in @($desktopShortcutPath, $startMenuShortcutPath)) {
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $exePath
        $shortcut.WorkingDirectory = $installDir
        $shortcut.IconLocation = "$exePath,0"
        $shortcut.Save()
    }

    Start-Process -FilePath $exePath -WorkingDirectory $installDir
}
finally {
    if (Test-Path $stagingDir) {
        Remove-Item $stagingDir -Recurse -Force
    }
}

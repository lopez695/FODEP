Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$backendDir = Join-Path $repoRoot "backend"
$frontendDir = Join-Path $repoRoot "frontend"
$distDir = Join-Path $repoRoot "dist"
$buildDir = Join-Path $repoRoot ".build"
$venvDir = Join-Path $buildDir "packaging-venv"
$venvPython = Join-Path $venvDir "Scripts\python.exe"
$portableDir = Join-Path $distDir "Risk management Portable"
$portableZipPath = Join-Path $distDir "Risk_Management_Portable.zip"
$payloadDir = Join-Path $buildDir "installer-payload"
$bundleZipPath = Join-Path $payloadDir "rwa_calculator_bundle.zip"
$installerExePath = Join-Path $distDir "Risk_Management_Setup.exe"
$installerSourcePath = Join-Path $repoRoot "scripts\InstallerStub.cs"
$installerBuildDir = Join-Path $buildDir "installer-build"
$frontendBuildDir = Join-Path $frontendDir "build\windows\x64"
$windowsAppIconPath = Join-Path $frontendDir "windows\runner\resources\app_icon.ico"
$embeddedPythonZipPath = Join-Path $buildDir "python-embed-amd64.zip"
$backendPackageDir = Join-Path $buildDir "backend-package"
$backendPythonDir = Join-Path $backendPackageDir "python"
$backendSourceDir = Join-Path $backendPackageDir "src"
$backendSeedDataDir = Join-Path $backendSourceDir "data"

function Stop-RwaCalculatorProcesses {
    $runningProcesses = Get-CimInstance Win32_Process -Filter "Name = 'rwa_calculator.exe'" -ErrorAction SilentlyContinue
    foreach ($process in $runningProcesses) {
        Write-Host "Arret du processus existant rwa_calculator.exe ($($process.ProcessId))" -ForegroundColor Yellow
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function New-CleanDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path $Path) {
        Remove-Item $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Host "==> $Title" -ForegroundColor Cyan
    & $Action
}

function Assert-LastExitCode {
    param([Parameter(Mandatory = $true)][string]$Context)

    if ($LASTEXITCODE -ne 0) {
        throw "$Context a échoué avec le code $LASTEXITCODE."
    }
}

function Resolve-MSBuildPath {
    $preferredPath = Join-Path $env:ProgramFiles "Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe"
    if (Test-Path $preferredPath) {
        return $preferredPath
    }

    $candidate = Get-ChildItem (Join-Path $env:ProgramFiles "Microsoft Visual Studio") -Recurse -Filter MSBuild.exe -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    if ($candidate) {
        return $candidate
    }

    throw "MSBuild.exe introuvable. Installez Visual Studio avec les outils desktop C++."
}

function Resolve-CSharpCompilerPath {
    $preferredPath = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (Test-Path $preferredPath) {
        return $preferredPath
    }

    $candidate = Get-ChildItem (Join-Path $env:WINDIR "Microsoft.NET") -Recurse -Filter csc.exe -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    if ($candidate) {
        return $candidate
    }

    throw "csc.exe introuvable. Installez le .NET Framework developer pack ou Visual Studio."
}

function Resolve-FlutterRoot {
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    if (-not $flutterCommand) {
        throw "flutter introuvable dans le PATH."
    }

    $flutterBin = Split-Path -Parent $flutterCommand.Source
    return Split-Path -Parent $flutterBin
}

function Get-FileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hashBytes = $sha256.ComputeHash($stream)
            return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "")
        }
        finally {
            $sha256.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Resolve-ExpectedReleaseFlutterEngine {
    $flutterRoot = Resolve-FlutterRoot
    $expectedEngine = Join-Path $flutterRoot "bin\cache\artifacts\engine\windows-x64-release\flutter_windows.dll"
    if (-not (Test-Path $expectedEngine)) {
        throw "Moteur Flutter release introuvable : $expectedEngine"
    }
    return $expectedEngine
}

function Copy-ReleaseFlutterEngineToBundle {
    $expectedEngine = Resolve-ExpectedReleaseFlutterEngine
    $bundleEngine = Join-Path (Join-Path $frontendBuildDir "runner\Release") "flutter_windows.dll"

    if (-not (Test-Path (Split-Path -Parent $bundleEngine))) {
        throw "Dossier du bundle release introuvable : $(Split-Path -Parent $bundleEngine)"
    }

    Copy-Item -LiteralPath $expectedEngine -Destination $bundleEngine -Force
}

function Resolve-FrontendBundlePath {
    $candidates = @(
        (Join-Path $frontendBuildDir "bundle")
        (Join-Path $frontendBuildDir "runner\Release")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate "rwa_calculator.exe")) {
            return $candidate
        }
    }

    throw "Executable Flutter introuvable. Emplacements testes : $($candidates -join ', ')"
}

function Clear-FlutterWindowsBuildState {
    Stop-RwaCalculatorProcesses

    $pathsToRemove = @(
        (Join-Path $frontendDir "build\windows")
        (Join-Path $frontendDir "windows\flutter\ephemeral")
    )

    foreach ($path in $pathsToRemove) {
        if (Test-Path $path) {
            Remove-Item $path -Recurse -Force
        }
        if (Test-Path $path) {
            throw "Nettoyage incomplet : $path est encore present."
        }
    }
}

function Assert-ReleaseFlutterEngine {
    $expectedEngine = Resolve-ExpectedReleaseFlutterEngine
    $bundleEngine = Join-Path (Join-Path $frontendBuildDir "runner\Release") "flutter_windows.dll"

    if (-not (Test-Path $bundleEngine)) {
        throw "Moteur Flutter absent du bundle release : $bundleEngine"
    }

    $expectedHash = Get-FileSha256 -Path $expectedEngine
    $bundleHash = Get-FileSha256 -Path $bundleEngine
    if ($expectedHash -ne $bundleHash) {
        throw "Bundle Flutter invalide : le moteur embarque n'est pas le moteur release."
    }
}

function Get-PythonVersion {
    return (& $venvPython -c "import sys; print(sys.version.split()[0])").Trim()
}

function Get-PythonTag {
    return (& $venvPython -c "import sys; print(f'python{sys.version_info.major}{sys.version_info.minor}')").Trim()
}

function Copy-IfExists {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not (Test-Path $Source)) {
        return
    }

    $destinationParent = Split-Path -Parent $Destination
    if ($destinationParent) {
        Ensure-Directory -Path $destinationParent
    }
    Copy-Item $Source $Destination -Force
}

function Copy-VCRuntimeDlls {
    param([Parameter(Mandatory = $true)][string]$TargetDir)

    # Embarque le runtime Visual C++ pour que l'application demarre sur des
    # postes ou le redistribuable n'est pas installe.
    $requiredDlls = @("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll")

    $redistCrtDir = Get-ChildItem (Join-Path $env:ProgramFiles "Microsoft Visual Studio") -Recurse -Directory -Filter "Microsoft.VC*.CRT" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "\\Redist\\" -and $_.FullName -match "\\x64\\" -and $_.FullName -notmatch "\\onecore\\" } |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName

    foreach ($dllName in $requiredDlls) {
        $sourceDll = $null
        if ($redistCrtDir -and (Test-Path (Join-Path $redistCrtDir $dllName))) {
            $sourceDll = Join-Path $redistCrtDir $dllName
        }
        elseif (Test-Path (Join-Path $env:WINDIR "System32\$dllName")) {
            $sourceDll = Join-Path $env:WINDIR "System32\$dllName"
        }

        if (-not $sourceDll) {
            throw "Runtime VC++ introuvable : $dllName. Installez Visual Studio avec les outils desktop C++."
        }
        Copy-Item $sourceDll (Join-Path $TargetDir $dllName) -Force
    }
}

function Resolve-PreferredWorkbookPath {
    $directCandidate = Join-Path $backendDir "data\modele_import_rwa.xlsx"
    if (Test-Path $directCandidate) {
        return $directCandidate
    }

    return $null
}

function Copy-BackendSeedData {
    param([Parameter(Mandatory = $true)][string]$TargetDataDir)

    Ensure-Directory -Path $TargetDataDir
    Copy-IfExists -Source (Join-Path $backendDir "data\rwa_data.db") -Destination (Join-Path $TargetDataDir "rwa_data.db")
    Copy-IfExists -Source (Join-Path $backendDir "data\exposure_metadata.json") -Destination (Join-Path $TargetDataDir "exposure_metadata.json")

    $preferredWorkbook = Resolve-PreferredWorkbookPath
    if ($preferredWorkbook) {
        Copy-Item $preferredWorkbook (Join-Path $TargetDataDir "modele_import_rwa.xlsx") -Force
        return
    }

    $generatorScript = @'
from pathlib import Path
import sys

repo_root = Path(sys.argv[1])
target_path = Path(sys.argv[2])
sys.path.insert(0, str(repo_root / "backend"))

from database.services.excel_import_service import excel_import_service

target_path.parent.mkdir(parents=True, exist_ok=True)
target_path.write_bytes(excel_import_service.build_template_workbook())
'@

    $targetWorkbookPath = Join-Path $TargetDataDir "modele_import_rwa.xlsx"
    $generatorScriptPath = Join-Path $buildDir "generate_template_workbook.py"
    Set-Content -Path $generatorScriptPath -Encoding Ascii -Value $generatorScript
    & $venvPython $generatorScriptPath $repoRoot $targetWorkbookPath
    Assert-LastExitCode -Context "La generation du modele Excel embarque"
}

Ensure-Directory -Path $distDir
Ensure-Directory -Path $buildDir

if (-not (Test-Path $venvPython)) {
    Invoke-Step -Title "Creation de l'environnement Python de packaging" -Action {
        python -m venv $venvDir
        Assert-LastExitCode -Context "La creation du venv Python"
    }
}

Invoke-Step -Title "Installation des dependances de packaging Python" -Action {
    & $venvPython -m pip install --upgrade pip
    Assert-LastExitCode -Context "La mise a jour de pip"
    & $venvPython -m pip install -r (Join-Path $backendDir "requirements.txt")
    Assert-LastExitCode -Context "L'installation des dependances Python"
}

Invoke-Step -Title "Assemblage du backend Python embarque" -Action {
    $pythonVersion = Get-PythonVersion
    $pythonTag = Get-PythonTag
    $embedUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-embed-amd64.zip"
    $sitePackagesDir = Join-Path $backendPythonDir "Lib\site-packages"
    $pthFilePath = Join-Path $backendPythonDir "$pythonTag._pth"

    New-CleanDirectory -Path $backendPackageDir
    Ensure-Directory -Path $backendPythonDir
    Ensure-Directory -Path $backendSourceDir
    Ensure-Directory -Path $backendSeedDataDir

    Invoke-WebRequest -Uri $embedUrl -OutFile $embeddedPythonZipPath
    Expand-Archive -Path $embeddedPythonZipPath -DestinationPath $backendPythonDir -Force
    Ensure-Directory -Path $sitePackagesDir

    & $venvPython -m pip install --upgrade --target $sitePackagesDir -r (Join-Path $backendDir "requirements.txt")
    Assert-LastExitCode -Context "L'installation des dependances dans le runtime Python embarque"

    Copy-Item (Join-Path $backendDir "app") $backendSourceDir -Recurse -Force
    Copy-Item (Join-Path $backendDir "database") $backendSourceDir -Recurse -Force
    Copy-Item (Join-Path $backendDir "run_server.py") $backendSourceDir -Force
    Copy-BackendSeedData -TargetDataDir $backendSeedDataDir

    Set-Content -Path $pthFilePath -Encoding Ascii -Value @(
        "$pythonTag.zip",
        ".",
        "Lib\site-packages",
        "..\src",
        "import site"
    )
}

Invoke-Step -Title "Compilation du frontend Flutter Windows" -Action {
    Push-Location $frontendDir
    try {
        Clear-FlutterWindowsBuildState
        flutter clean
        Assert-LastExitCode -Context "flutter clean"
        flutter pub get
        Assert-LastExitCode -Context "flutter pub get"
        flutter build windows --release --no-tree-shake-icons
        Assert-LastExitCode -Context "flutter build windows --release --no-tree-shake-icons"
        Copy-ReleaseFlutterEngineToBundle
        Assert-ReleaseFlutterEngine
    }
    finally {
        Pop-Location
    }
}

Invoke-Step -Title "Creation explicite du bundle Windows Flutter" -Action {
    $msbuildExe = Resolve-MSBuildPath
    & $msbuildExe (Join-Path $frontendBuildDir "INSTALL.vcxproj") /p:Configuration=Release /p:Platform=x64 /m
    Assert-LastExitCode -Context "La creation du bundle Windows via MSBuild"
    Copy-ReleaseFlutterEngineToBundle
    Assert-ReleaseFlutterEngine
}

Invoke-Step -Title "Assemblage du livrable portable" -Action {
    $frontendBundleDir = Resolve-FrontendBundlePath
    if (-not (Test-Path (Join-Path $frontendBundleDir "rwa_calculator.exe"))) {
        throw "Executable Flutter introuvable dans $frontendBundleDir"
    }
    if (-not (Test-Path (Join-Path $backendPythonDir "python.exe"))) {
        throw "Runtime Python embarque introuvable dans $backendPythonDir"
    }
    if (-not (Test-Path (Join-Path $backendSourceDir "run_server.py"))) {
        throw "Lanceur backend introuvable dans $backendSourceDir"
    }

    New-CleanDirectory -Path $portableDir
    Copy-Item (Join-Path $frontendBundleDir "*") $portableDir -Recurse -Force
    Copy-Item $backendPackageDir (Join-Path $portableDir "backend") -Recurse -Force
    Copy-VCRuntimeDlls -TargetDir $portableDir
}

Invoke-Step -Title "Compression du livrable portable" -Action {
    if (Test-Path $portableZipPath) {
        Remove-Item $portableZipPath -Force
    }

    Compress-Archive -Path (Join-Path $portableDir "*") -DestinationPath $portableZipPath -CompressionLevel Optimal
}

Invoke-Step -Title "Preparation du paquet d'installation" -Action {
    New-CleanDirectory -Path $payloadDir

    if (Test-Path $bundleZipPath) {
        Remove-Item $bundleZipPath -Force
    }
    Compress-Archive -Path (Join-Path $portableDir "*") -DestinationPath $bundleZipPath -CompressionLevel Optimal
}

Invoke-Step -Title "Compilation de l'installateur EXE autonome" -Action {
    $cscExe = Resolve-CSharpCompilerPath
    New-CleanDirectory -Path $installerBuildDir
    if (Test-Path $installerExePath) {
        Remove-Item $installerExePath -Force
    }

    $compilerArguments = @(
        "/nologo",
        "/target:winexe",
        "/platform:x64",
        "/out:$installerExePath",
        "/resource:$bundleZipPath,RwaCalculator.Bundle.zip",
        "/reference:System.dll",
        "/reference:System.Core.dll",
        "/reference:System.IO.Compression.dll",
        "/reference:System.IO.Compression.FileSystem.dll",
        "/reference:System.Windows.Forms.dll",
        "/reference:Microsoft.CSharp.dll"
    )
    if (Test-Path $windowsAppIconPath) {
        $compilerArguments += "/win32icon:$windowsAppIconPath"
    }
    $compilerArguments += $installerSourcePath

    & $cscExe @compilerArguments
    Assert-LastExitCode -Context "La compilation de l'installateur autonome"
    if (-not (Test-Path $installerExePath)) {
        throw "L'installateur autonome n'a pas été généré."
    }
}

Write-Host ""
Write-Host "Portable :" -ForegroundColor Green
Write-Host "  $portableDir"
Write-Host "Portable ZIP :" -ForegroundColor Green
Write-Host "  $portableZipPath"
Write-Host "Installateur EXE :" -ForegroundColor Green
Write-Host "  $installerExePath"

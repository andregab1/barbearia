[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterProject = Join-Path $repoRoot 'app'
$buildDirectory = Join-Path $flutterProject 'build\web'

function Fail([string] $Message) {
    Write-Host "VALIDAÇÃO DO FRONTEND FALHOU: $Message" -ForegroundColor Red
    exit 1
}

function Resolve-Flutter {
    if ($env:FLUTTER_EXE -and (Test-Path -LiteralPath $env:FLUTTER_EXE)) {
        return (Resolve-Path -LiteralPath $env:FLUTTER_EXE).Path
    }
    $candidates = @('C:\flutter\bin\flutter.bat')
    if ($env:FLUTTER_ROOT) { $candidates = @((Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat')) + $candidates }
    $candidates = @($candidates | Where-Object { Test-Path -LiteralPath $_ })
    if ($candidates.Count -gt 0) { return (Resolve-Path -LiteralPath $candidates[0]).Path }
    foreach ($commandName in @('flutter.bat', 'flutter')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Source }
    }
    Fail 'Flutter não foi encontrado. Defina FLUTTER_EXE ou configure o Flutter no PATH.'
}

function Invoke-FlutterAnalyze([string] $Flutter) {
    Write-Host '== flutter analyze ==' -ForegroundColor Cyan
    Push-Location $flutterProject
    try {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $outputLines = @(& $Flutter analyze --no-pub 2>&1)
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousPreference
        $output = ($outputLines -join [Environment]::NewLine)
        if ($output) { Write-Host $output }
        $hasErrors = ($output -match '(?im)^\s*error\s+-') -or ($output -match '(?im)\berror\s*[:：]')
        if ($hasErrors) { Fail 'flutter analyze encontrou erros impeditivos.' }
        if ($exitCode -ne 0) { Write-Host "flutter analyze terminou com exit code $exitCode, mas apenas warnings/infos foram encontrados." -ForegroundColor Yellow }
        else { Write-Host 'flutter analyze concluído sem erros impeditivos.' -ForegroundColor Green }
    } catch {
        Fail "flutter analyze falhou: $($_.Exception.Message)"
    } finally {
        Pop-Location
    }
}

function Invoke-Flutter([string] $Flutter, [string[]] $Arguments, [string] $Step) {
    Write-Host "== $Step ==" -ForegroundColor Cyan
    Push-Location $flutterProject
    try {
        & $Flutter @Arguments
        if ($LASTEXITCODE -ne 0) { Fail "$Step retornou exit code $LASTEXITCODE." }
    } catch {
        Fail "$Step falhou: $($_.Exception.Message)"
    } finally {
        Pop-Location
    }
}

function Get-BytesHash([byte[]] $Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-UrlBytes([string] $Uri) {
    $client = New-Object System.Net.WebClient
    try {
        $bytes = $client.DownloadData($Uri)
        return [PSCustomObject]@{ StatusCode = 200; Bytes = $bytes }
    } catch [System.Net.WebException] {
        $response = $_.Exception.Response
        if (-not $response) { throw }
        $stream = $response.GetResponseStream()
        $memory = New-Object System.IO.MemoryStream
        try {
            $stream.CopyTo($memory)
            return [PSCustomObject]@{ StatusCode = [int]$response.StatusCode; Bytes = $memory.ToArray() }
        } finally {
            $stream.Dispose()
            $memory.Dispose()
        }
    } finally { $client.Dispose() }
}

if (-not (Test-Path -LiteralPath $flutterProject -PathType Container)) { Fail "Diretório Flutter não encontrado: $flutterProject" }
$flutter = Resolve-Flutter
$required = @('index.html', 'flutter_bootstrap.js', 'flutter.js', 'version.json')
$beforeState = @{}
if (Test-Path -LiteralPath $buildDirectory) {
    foreach ($name in $required) {
        $file = Join-Path $buildDirectory $name
        if (Test-Path -LiteralPath $file) { $beforeState[$name] = (Get-Item -LiteralPath $file).LastWriteTimeUtc }
    }
}

Invoke-FlutterAnalyze $flutter
$buildStarted = [DateTime]::UtcNow
Invoke-Flutter $flutter @('build', 'web', '--release', '--no-pub', '--no-wasm-dry-run') 'flutter build web'

if (-not (Test-Path -LiteralPath $buildDirectory -PathType Container)) { Fail "O diretório de build não foi gerado: $buildDirectory" }
$artifactNames = @('main.dart.js', 'flutter_bootstrap.js', 'flutter.js', 'version.json', 'index.html')
$artifacts = @($artifactNames | ForEach-Object { $file = Join-Path $buildDirectory $_; if (Test-Path -LiteralPath $file) { Get-Item -LiteralPath $file } })
if ($artifacts.Count -eq 0) { Fail 'Nenhum artefato Flutter Web esperado foi encontrado.' }
if (-not ($artifacts | Where-Object { $_.Name -in @('main.dart.js', 'flutter_bootstrap.js', 'version.json', 'index.html') })) { Fail 'Os artefatos principais do Flutter Web não foram encontrados.' }
$updated = @($artifacts | Where-Object { $_.LastWriteTimeUtc -ge $buildStarted })
if ($updated.Count -eq 0) { Fail 'Nenhum artefato principal foi atualizado após o build; o build antigo pode continuar sendo servido.' }
Write-Host "Artefatos atualizados: $($updated.Name -join ', ')" -ForegroundColor Green

$localIndex = Join-Path $buildDirectory 'index.html'
try {
$rootResponse = Get-UrlBytes 'http://localhost:3000/'
    if ($rootResponse.StatusCode -lt 200 -or $rootResponse.StatusCode -ge 400) { Fail "localhost:3000 retornou HTTP $($rootResponse.StatusCode)." }
$localHash = Get-BytesHash ([System.IO.File]::ReadAllBytes($localIndex))
$servedHash = Get-BytesHash $rootResponse.Bytes
    if ($localHash -ne $servedHash) { Fail 'localhost:3000 não corresponde ao index.html atual de app/build/web.' }
    Write-Host "localhost:3000 respondeu HTTP $($rootResponse.StatusCode) e corresponde ao build atual." -ForegroundColor Green
} catch { Fail "Não foi possível validar localhost:3000: $($_.Exception.Message)" }

try {
$healthResponse = Get-UrlBytes 'http://localhost:3000/health'
    if ($healthResponse.StatusCode -eq 404) {
        Write-Host 'Aviso: /health não existe por design; validação principal mantida.' -ForegroundColor Yellow
    } elseif ($healthResponse.StatusCode -lt 200 -or $healthResponse.StatusCode -ge 400) {
        Fail "localhost:3000/health retornou HTTP $($healthResponse.StatusCode)."
    } else {
        Write-Host "localhost:3000/health respondeu HTTP $($healthResponse.StatusCode)." -ForegroundColor Green
    }
} catch { Fail "Não foi possível validar localhost:3000/health: $($_.Exception.Message)" }

Write-Host 'FRONTEND VALIDADO COM SUCESSO' -ForegroundColor Green
exit 0

# 把 Gradle / Flutter / 临时目录都指到 D:，避免 C 盘满导致打 APK 失败
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$buildHome = "D:\build-home"
New-Item -ItemType Directory -Force -Path @(
  "$buildHome\gradle",
  "$buildHome\flutter-pub-cache",
  "$buildHome\temp"
) | Out-Null

$env:GRADLE_USER_HOME = "$buildHome\gradle"
$env:PUB_CACHE = "$buildHome\flutter-pub-cache"
$env:TEMP = "$buildHome\temp"
$env:TMP = "$buildHome\temp"
$env:TMPDIR = "$buildHome\temp"
# Android / Java 临时文件
$env:JAVA_TOOL_OPTIONS = "-Djava.io.tmpdir=D:/build-home/temp"

Write-Host "GRADLE_USER_HOME=$env:GRADLE_USER_HOME"
Write-Host "PUB_CACHE=$env:PUB_CACHE"
Write-Host "TEMP=$env:TEMP"
Write-Host "C free GB: $([math]::Round((Get-PSDrive C).Free/1GB,2))"
Write-Host "D free GB: $([math]::Round((Get-PSDrive D).Free/1GB,2))"

flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apk = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) {
  $len = (Get-Item $apk).Length
  Write-Host "OK: $apk ($([math]::Round($len/1MB,2)) MB)"
} else {
  Write-Host "Build finished but APK not found at $apk"
  exit 1
}

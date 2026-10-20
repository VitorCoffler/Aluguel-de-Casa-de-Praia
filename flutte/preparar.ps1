$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
# Flutter cria os diretórios nativos; os arquivos personalizados são preservados.
flutter create --empty --project-name casa_da_praia --platforms=android,web .
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível preparar o projeto Flutter.' }
$mainManifest = Join-Path $PSScriptRoot 'android/app/src/main/AndroidManifest.xml'
$text = Get-Content $mainManifest -Raw
if ($text -notmatch 'android.permission.INTERNET') {
  $text = $text -replace '(<manifest[^>]*>)', '$1<uses-permission android:name="android.permission.INTERNET" />'
}
if ($text -notmatch 'android:allowBackup=') {
  $text = $text -replace '<application', '<application android:allowBackup="false"'
}
Set-Content $mainManifest -Value $text -Encoding UTF8
$debugDir = Join-Path $PSScriptRoot 'android/app/src/debug'
New-Item -ItemType Directory -Force $debugDir | Out-Null
@'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:usesCleartextTraffic="true" />
</manifest>
'@ | Set-Content (Join-Path $debugDir 'AndroidManifest.xml') -Encoding UTF8
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível instalar as dependências.' }
Write-Host 'Preparado. Execute: flutter run -d chrome --web-port 5300 --dart-define=API_URL=http://localhost:4000'

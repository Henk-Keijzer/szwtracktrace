#./build-variant szw/sv/oly
#
# Dit PowerShell script maakt de executables voor Web, Android en Windows, voor de als parameter aangegeven variant
# Voor elke variant moet je een folder maken in de folder variants/xxx (kopieer van een andere variant) met daarin
# 1. een main.dart met daarin de baseURL van de variant
# 2. een bestand flutter_launcher_icons.yaml met daarin per platform de verwijzing naar de icon file voor de variant
# 3. en natuurlijk dat icon bestandje (maar dat mag ook ergens anders staan)
# 4. een bestand manifest.json (voor web)
# 5. een bestand key.properties en een bestand upload-keystore.jks (voor android, zie instructies hieronder)
#
# Maak een upload-keystore.jks bestand met het volgende PowerShell commando:
#    >keytool -genkey -v -keystore variants/zzz/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
# Edit het bestand variants/xxx/key.properties met store- en keyPassword
#
# Tenslotte in dit bestand (build-variant.ps1) een elseif-blokje met appname en appbundle voor de variant hieronder toevoegen
#
Param ($variant)

if ($variant -eq 'szw') {
    $appname = 'SZW Track Trace'
    $appbundle = 'nl.zeilvaartwarmond.szwtracktrace'
} elseif ($variant -eq 'sv') {
    $appname = 'Sportvolgen TT'
    $appbundle = 'nl.sportvolgen.svtracktrace'
} elseif ($variant -eq 'sr') {
    $appname = 'Sportvolgen sloeproeien'
    $appbundle = 'nl.sportvolgen.srtracktrace'
} elseif ($variant -eq 'cr') {
    $appname = 'Sportvolgen coastal roeien'
    $appbundle = 'nl.sportvolgen.crtracktrace'
} elseif ($variant -eq 'mr') {
    $appname = 'Sportvolgen marathon roeien'
    $appbundle = 'nl.sportvolgen.mrtracktrace'
} elseif ($variant -eq 'pgr') {
    $appname = 'Sportvolgen pilot gig roeien'
    $appbundle = 'nl.sportvolgen.pgrtracktrace'
} elseif ($variant -eq 'olympia') {
    $appname = 'Olympia Charters TT'
    $appbundle = 'nl.olympiacharters.olytracktrace'
} else {
    exit
}

# rename appname and appbundle
rename setAppName --value $appname --targets android,ios,web,windows,macos
rename setBundleId --value $appbundle --targets android,ios,web,windows,macos

# create the icons for all platforms using the appropriate yaml file. De yaml file moet
# volgens de documentatie in dezelfde folder als pubspec.yaml staan...
Copy-Item -Path "variants/$variant/flutter_launcher_icons.yaml" -Destination "flutter_launcher_icons.yaml"
dart run flutter_launcher_icons flutter_launcher_icons.yaml

# copy the variant/xxx/main.dart to lib/main.dart (so we always build main.dart)
Copy-Item -Path "variants\$variant\main.dart" -Destination "lib\main.dart"

# make sure all destinations in the release folder exist, so we can copy files there
New-Item -Path release -Type Directory -ErrorAction SilentlyContinue
New-Item -Path release\$variant -Type Directory -ErrorAction SilentlyContinue
New-Item -Path release\$variant\web -Type Directory -ErrorAction SilentlyContinue
New-Item -Path release\$variant\android -Type Directory -ErrorAction SilentlyContinue
New-Item -Path release\$variant\windows -Type Directory -ErrorAction SilentlyContinue
New-Item -Path release\$variant\windows\dummy -Type Directory -ErrorAction SilentlyContinue
New-Item -Path release\$variant\ios -Type Directory -ErrorAction SilentlyContinue

# build for web and copy correct manifest in the release/xxx/web folder
flutter build web --output "release\$variant\web\"
Remove-Item -Path "release\$variant\web\manifest.json"
Copy-Item -Path "variants\$variant\manifest.json" -Destination "release\$variant\web\manifest.json"

# copy the upload-keystore.jks and key.properties file for this variant to the correct locations
Copy-Item -Path "variants\$variant\upload-keystore.jks" -Destination "android\app\upload-keystore.jks"
Copy-Item -Path "variants\$variant\key.properties" -Destination "android\key.properties"

# build the Android App Bundle
flutter build appbundle
Copy-Item -Path "build\app\outputs\bundle\release\app-release.aab" -Destination "release\$variant\android\$variant-app-release.aab"

# build the Android Package
flutter build apk
Copy-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -Destination "release\$variant\android\$variant-app-release.apk"

# build the Windows executable and the Windows msix package
# TODO do something with the msix parameters in pubspec.yaml, now only available for szw variant
dart run msix:create
Remove-Item -Path "release\$variant\windows\*" -Recurse
Copy-Item -Path "build\windows\x64\runner\Release\*" -Destination "release\$variant\windows\" -Recurse

Write-Host ""
Write-Host "+-------------------------------------------------------------------------------------------------------------------"
Write-Host "| Output for Android (APK and signed AAB), Web and Windows are in the folders release/$variant/android | web | windows"
Write-Host "|"
Write-Host "| For building variant $variant for iOS and macOS:"
Write-Host "| 0. (do not re-run this script for another variant...)"
Write-Host "| 1. commit the Project as it is now to GitHub, branch master"
Write-Host "| 2. goto https://www.CodeMagic.io and build the iOS app and macOS package for $variant"
Write-Host "+-------------------------------------------------------------------------------------------------------------------"
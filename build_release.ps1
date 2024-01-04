#./build_release szw|sv/oly
#
# Dit scriptje maakt de executables voor Web, Android en Windows, voor de aangegeven variant
# Voor elke variant moet je:
# 1. een lib\main-xxx.dart maken met daarin de baseURL van de variant
# 2. een bestand flutter_launcher_icons_xxx.yaml maken met daarin de verwijzing naar de icon file voor de variant
#    en natuurlijk dat icon bestandje
# 3. een bestand web\xxx-manifest.json maken
# 4. een if-blokje met appname en appbundle voor de variant hieronder toevoegen
#
Param ($variant)

if ($variant -eq 'szw') {
    $appname = 'SZW Track Trace'
    $appbundle = 'nl.zeilvaartwarmond.szwtracktrace'
} elseif ($variant -eq 'sv') {
    $appname = 'Sportvolgen TT'
    $appbundle = 'nl.sportvolgen.svtracktrace'
} elseif ($variant -eq 'oly') {
    $appname = 'Olympia Charters TT'
    $appbundle = 'nl.olympiacharters.olytracktrace'
} else {
    exit
}

# rename appname and appbundle
rename setAppName --value $appname --targets android,ios,web,windows,macos
rename setBundleId --value $appbundle --targets android,ios,web,windows,macos

# create the icons for all platforms using the appropriate yaml file
dart run flutter_launcher_icons -f flutter_launcher_icons_$variant.yaml

# copy the variant main-xxx.dart to main.dart (so we always build main.dart)
Copy-Item -Path "lib\main_$variant.dart" -Destination "lib\main.dart"

New-Item -Path out -Type Directory -ErrorAction SilentlyContinue
New-Item -Path out\$variant -Type Directory -ErrorAction SilentlyContinue
New-Item -Path out\$variant\web -Type Directory -ErrorAction SilentlyContinue
New-Item -Path out\$variant\android -Type Directory -ErrorAction SilentlyContinue
New-Item -Path out\$variant\windows -Type Directory -ErrorAction SilentlyContinue
New-Item -Path out\$variant\windows\dummy -Type Directory -ErrorAction SilentlyContinue
New-Item -Path out\$variant\ios -Type Directory -ErrorAction SilentlyContinue

# build for web and set correct manifest in the output folder
flutter build web --output "out\$variant\web\"
Remove-Item -Path "out\$variant\web\manifest*.json"
Copy-Item -Path "web\manifest_$variant.json" -Destination "out\$variant\web\manifest.json"

New-Item -Path out\$variant\android -Type Directory -ErrorAction SilentlyContinue

# build the Android App Bundle TODO using the correct keystore
flutter build appbundle
Copy-Item -Path "build\app\outputs\bundle\release\app-release.aab" -Destination "out\$variant\android\"

# build the Android Package
flutter build apk
Copy-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -Destination "out\$variant\android\"

# build the Windows executable and the Windows msix package
# TODO do something with the msix parameters in pubspec.yaml, now only available for szw variant
dart run msix:create
#Remove-Item -Path "out\$variant\windows\*.*" -Recurse
Remove-Item -Path "out\$variant\windows\*" -Recurse
Copy-Item -Path "build\windows\x64\runner\Release\*" -Destination "out\$variant\windows\" -Recurse

Write-Host ""
Write-Host "+-------------------------------------------------------------------------------------------------------------------"
Write-Host "| Output for Android (APK and signed AAB), Web and Windows are in the folders out/$variant/android | web | windows"
Write-Host "|"
Write-Host "| For building this variant $variant for iOS and macOS:"
Write-Host "| 1. commit the Project as it is now to GitHub, branch master"
Write-Host "| 2. goto www.CodeMagic.io and build the iOS app and macOS package for $variant"
Write-Host "+-------------------------------------------------------------------------------------------------------------------"
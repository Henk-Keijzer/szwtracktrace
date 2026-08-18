#./build-variant szw/sv/olympia
#
# Dit PowerShell script maakt de executables voor Web, Android en Windows, voor de als parameter aangegeven variant
# Voor elke variant moet je een folder maken in de folder variants/xxx (kopieer van een andere variant) met daarin
# 1. een main.dart met daarin de baseURL van de variant (de server, bijvoorbeeld https://tt.zeilvaartwarmond.nl/ (dus met afsluitende slash))
# 2. een bestand flutter_launcher_icons.yaml met daarin per platform de verwijzing naar de icon file voor de variant
# 3. en natuurlijk dat icon bestandje (maar dat mag ook ergens anders staan)
# 4. een bestand manifest.json (voor web)
# 5. een bestand key.properties en een bestand upload-keystore.jks (voor android, zie instructies hieronder)
#
# Maak een upload-keystore.jks bestand met het volgende PowerShell commando:
#    >keytool -genkey -v -keystore variants/xxx/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
# In de Play Store kun je aangeven dat je je upload key kwijt bent. Play Store geeft dan de mogelijkheid om met het bestand upload-key.jks
# een de nieuwe upload key bij de playstore bekend te maken (bij de volgende uploads is dat dan niet meer nodig)
#
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
} elseif ($variant -eq 'svskiff') {
    $appname = 'Sportvolgen TT skiff'
    $appbundle = 'nl.sportvolgen.svskifftracktrace'
} elseif ($variant -eq 'svzeilen') {
    $appname = 'Sportvolgen TT zeilen'
    $appbundle = 'nl.sportvolgen.svzeilentracktrace'
} elseif ($variant -eq 'olympia') {
    $appname = 'Olympia Charters TT'
    $appbundle = 'nl.olympiacharters.olytracktrace'
} elseif ($variant -eq 'sar') {
    $appname = 'Search and Rescue TT'
    $appbundle = 'nl.sar.tracktrace'
} else {
    exit
}

# rename appname and appbundle
rename setAppName --value $appname --targets android,ios,web,windows,macos
rename setBundleId --value $appbundle --targets android,ios,web,windows,macos

# create the icons for all platforms using the appropriate yaml file. De yaml file moet
# volgens de documentatie in dezelfde folder als pubspec.yaml staan...
Copy-Item -Path "variants\$variant\flutter_launcher_icons.yaml" -Destination "flutter_launcher_icons.yaml"
dart run flutter_launcher_icons flutter_launcher_icons.yaml
# flutter_launcher_icons maakt een directory aan die ervoor zorgt dat de app niet goed geinstalleerd kan worden
# (tijdelijke) oplossing hele directory wissen en het loopt verder goed.
# Remove-Item -Path android/app/src/main/res/mipmap-anydpi-v26 -Recurse

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


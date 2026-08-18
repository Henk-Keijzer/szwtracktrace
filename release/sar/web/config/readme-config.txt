config folder

The config folder contains the following files:

-	app-info-page.html
	This HTML file will be shown in the app when the user hits the (i) button in the appbar.
	It can be tailored to whatever you want, but you need to mention the copyright owner: Stichting
	Zeilvaart Warmond.
	
-	appicon.png
	This is the default image that you see at the top left of the screen. You can overrule it for 
	each individual event.

-	dbinfo.php
	This PHP file defines the four items needed for the mySQL database: hostname, database name,
	user name and user password.
	For the admin pages to work properly you need to get a Google Maps API key that allows you to
	use Google Maps. Goto https://console.cloud.google.com/, use your Google account, goto API's =>
	credentials, create a key for your domain and enable Geocoding API and Maps Javascript API.
	When you use the AIS services of AISHub or Marinetraffic, you need to enter the access keys 
	for these services here also.
	
-	favicon.png
	This is the one and only icon shown in the tab of the browser. You cannot overrule it for
	individual events (yet).
	
-	flutter-config.json
	This file contains a limited set of app branding settings: some texts, app colors and icons

-	maptileproviders.json	
	File with the definition of the maps the user can select. There is a set of base maps and
	(optionally) a set of overlay maps. Currently only WMS and WMTS maptile providers are supported.
	
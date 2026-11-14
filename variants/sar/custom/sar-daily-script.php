<?php
	include '../config/dbinfo.php';
	date_default_timezone_set('CET');

	$start = strtotime('yesterday 00:00:00');
	$end = strtoTime('today 00:00:00') -1;	//yesterday 23:59:59

	// create some strings
	$foldername = date('Y-m-d', $start);
	$weekday = array('Zondag','Maandag','Dinsdag','Woensdag','Donderdag','Vrijdag','Zaterdag');
	$month = array('januari','februari','maart','april','mei','juni','juli','augustus','september','oktober','november','december');
	$eventtitle = 'Search & Rescue ' . $weekday[date('w', $start)] . ', ' . date('d ', $start) . $month[date('m', $start)-1] . date(' Y', $start);
	
	// create the new event folder using the date as foldername
	$newpath = "../data/Reddingboten/" . $foldername;
	$newdomain = 'Reddingboten/'.$foldername;
	mkdir($newpath);
	
	// get the default event json file
	$event = json_decode(file_get_contents('../data/Reddingboten/_default/event.json'), true);
	
	//replace eventid, eventtitle and start and end times
	$event['eventid'] = 'Reddingboten-' . $foldername;
	$event['eventtitle'] = $eventtitle;
	$event['eventstartstamp'] = strval($start);
	$event['eventendstamp'] = strval($end);
	// store the event file in the new directory
	file_put_contents($newpath . '/event.json', json_encode($event));
	// copy some other files there as well
	copy ('../data/Reddingboten/_default/BRwindstations.json', $newpath . '/BRwindstations.json');
	copy ('../data/Reddingboten/_default/logo.png', $newpath . '/logo.png');
	copy ('../data/Reddingboten/_default/route.geojson', $newpath . '/route.geojson');


	// copy the participants of the live event to the new event
	file_get_contents("https://sar.zeilvaartwarmond.nl/admin/me-handle-request.php?auth=special_script&req=copy-participants&event=Reddingboten/Live&newevent=".$newdomain);

	// and copy the gpsbuoys of the live event to the new event
	file_get_contents("https://sar.zeilvaartwarmond.nl/admin/me-handle-request.php?auth=special_script&req=copy-gpsbuoys&event=Reddingboten/Live&newevent=".$newdomain);

	// force the system to generate a replaytracks.json file
	file_get_contents("https://sar.zeilvaartwarmond.nl/get?req=replay&event=".$newdomain."&nostats=true");
	
	// one week back 7 * 24 * 60 * 60 = 604800)
	$eventtodelete = 'Reddingboten/' . date('Y-m-d', $start - 604800);
	
	// delete the old event
	file_get_contents("https://sar.zeilvaartwarmond.nl/admin/me-handle-request.php?auth=special_script&req=delete-event&event=" . $eventtodelete);

	// delete old AIS positions from the traces table
	$connection = mysqli_connect ($dbhost, $dbuser, $dbpassw, $dbname);
	$query = "SELECT * FROM `participants` WHERE `eventdomain` LIKE 'Reddingboten/Live';";
	$result = mysqli_query($connection, $query);
	while ($data = mysqli_fetch_assoc($result)) {
		$tracker = $data['trackerid'];
		$query = "DELETE FROM `traces` WHERE `ship` = '{$tracker}' AND `timestamp` < " . (time() - (8 * 24 * 60 * 60)) . ";";
		mysqli_query($connection, $query);
	}
	// delete old statistics from the stats table
	$query = "DELETE FROM `stats` WHERE `event` like 'Reddingboten%' AND `stamp` < '" . date('Y-m-d', $start - 604800) . "';";
	mysqli_query($connection, $query);
	//
	// and thats'it	
	mysqli_close($connection);
?>
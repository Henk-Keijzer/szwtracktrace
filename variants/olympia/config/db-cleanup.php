<?php
	include '../config/dbinfo.php';
	$con = mysqli_connect($dbhost, $dbuser, $dbpassw, $dbname); 
	if ($con != false)
	{	$ninetydaysago = time() - (90*24*60*60);
		$query = 'DELETE FROM oltrackdb.traces WHERE timestamp < ' . $ninetydaysago;
echo $query . '<br>';
		$result = mysqli_query($con, $query);
echo $result;
	}
	mysqli_close($con);
?>
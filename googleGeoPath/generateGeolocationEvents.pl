#----------------------------------------------------------------------------------------------------------------------------------------------
#--------------------------------------------- Alessandro Cagnetti <alessandro.cagnetti@solace.com>  ------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------ GENERATEGEOLOCATIONEVENTS V0.1 --------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------------------------
# "GenerateGeolocationEvents" is a Perl script to generate movement events of people and in general any moving vehicule and publish them to a MQTT broker.
# The script takes in input a CSV file containing an export of paths and zones created with Google Maps Editor to generate movement paths and uses zones 
# to detect movement events into specific delimited geografical zones.
# This script works in tandem with a specific Google maps custom web page with javascript logic and Zone detector program with a Solace Event Mesh 
#----------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------- Copyright Solace Corporation----------------------------------------------------------
#-------------------------------------------------------------- www.solace.com ----------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------------------------

#use strict;
#use warnings;
#use Encode qw(encode_utf8);
#use HTTP::Request ();
#use JSON::MaybeXS qw(encode_json);
#use LWP::UserAgent;
#use REST::Client;
#use MIME::Base64;
use Net::MQTT::Simple;
use Getopt::Long;
use Time::HiRes qw(time);
use IO::Socket::IP;
use POSIX qw(strftime);
use Net::MAC;
use Geo::Calc::XS;
use Time::HiRes qw(usleep nanosleep);
use Math::Trig 'pi', 'rad2deg';

#print "ONE COMMAND LINE:".$ARGV[0]." ".$ARGV[1]." ".$ARGV[2]." ".$ARGV[3]." ".$ARGV[4]." ".$ARGV[5]." ".$ARGV[6]." ".$ARGV[7]." ".$ARGV[8]." ".$ARGV[9]." ".$ARGV[10]." ".$ARGV[11]." ".$ARGV[12]."\n\n";

die "\n\nGENERATEGEOLOCATIONEVENTS Error, execute  command line parameters:\n\nperl generateGeoLocationEvents.pl [AIRCRAFT [TAXIING|RUNWAY] <Flight Number>|PEOPLE|VEHICLE <Vehicle Number>|GEOFENCEONLY] <geofenceLabel(s)> <googleMapsExportFile(s)> <SolaceBrokerURL:Port> <SolaceBrokerUserName> <SolaceBrokerPassword> \n\n" if scalar (@ARGV) < 2;

my $mqtt_username = "";
my $mqtt_password = "";
my $url = '';

# read first command line and print it
my $geolocationType = $ARGV[0];
my $numParameters = $#ARGV;
print "\/\/$numParameters arguments passed to script \n";
print "\/\/Geolocation Type selected: $geolocationType\n";

if ($geolocationType eq 'AIRCRAFT'){
	$aircraftMovementType = $ARGV[1];
	$newPlaneflightNumber = $ARGV[2];
	$googleMapsExportFile = $ARGV[3];
	$mqtt_username = $ARGV[5];
    $mqtt_password = $ARGV[6];
    $url = $ARGV[4];
	print "requested to add Flight Number: $newPlaneflightNumber\n";
}
elsif ($geolocationType eq 'VEHICLE'){
	$newVehiculeNumber = $ARGV[1];
	$googleMapsExportFile = $ARGV[2];
	$mqtt_username = $ARGV[4];
    $mqtt_password = $ARGV[5];
    $url = $ARGV[3];
	print "requested to add Vehicle Number: $newVehiculeNumber\n";
}
elsif ($geolocationType eq 'PEOPLE'){
	$googleMapsExportFile = $ARGV[1];
    $mqtt_username = $ARGV[3];
    $mqtt_password = $ARGV[4];
    $url = $ARGV[2];
}
elsif ($geolocationType eq 'GEOFENCEONLY'){
	# read all the input files names (first one is only javascript output file name)
	for ($zz=1;$zz<=($numParameters/2);$zz++) {
		$googleMapsExportFiles[$zz] = $ARGV[$zz*2];
		$geofenceTags[$zz] = $ARGV[($zz-1)*2+1];
	}
}


# Allow unencrypted connection with credentials
$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;


my $destinationTopicPrefix = "geo/situation/track/v1";
my $people = {};
my $dateTimeString = "";

# number of ingested path from google export
my $numberOfLineStrings = 0;
#time in seconds plane waits at gate before leaving
my $planeWaitTimeAtGate = 30;
# default random seed for planes heading when parked or stop at destination
my $startingHeading = 90;
my $mqtt = "";
my $fileHandleArray;  

# if NOT geofencing only
if (!($geolocationType eq 'GEOFENCEONLY')){ 
	# Connect to broker only if not doing geofencing only (no connection to broker needeD)
	$mqtt = Net::MQTT::Simple->new($url);
	print "connnecting to $url...\n";
	$mqtt->login($mqtt_username, $mqtt_password);
	print "logged in\n";

	print "Google maps export file filepath and name: $googleMapsExportFile\n";
	#open files for read
	open(IN, "<$googleMapsExportFile") or die "Error opening google maps export file $googleMapsExportFile";
	#die ("the end...");
}
else # if geofencing only
{
	for ($tt=1;$tt<=($numParameters/2);$tt++) {
		print "\/\/Google maps export file filepath and name: $googleMapsExportFiles[$tt] tagged \'$geofenceTags[$tt]\'\n";
		#open files for read
		open($fileHandleArray[$tt], "<$googleMapsExportFiles[$tt]") or die "Error opening google maps export file $googleMapsExportFiles[$tt]";
		print "\/\/opened file $tt $googleMapsExportFiles[$tt]\n";
	}
}
  
 # calculate heaading from vector (initial and final coordinates)
sub calcHeading{
	my ( $ilat, $ilon, $flat, $flon )=@_; 
	$gcInitial = Geo::Calc::XS->new( lat => $flat, lon => $flon );
	$gcFinal = Geo::Calc::XS->new( lat => $ilat, lon => $ilon );
	return $gcInitial->final_bearing_to($gcFinal,0);
}	

#print "heading: ".calcHeading(41,12,41,13) ;
#die "stop\n";
 
sub addPerson {
	$newMacaddr = genMacAddress();
	my $mac = Net::MAC->new('mac' => $newMacaddr);
	my $dec_mac = $mac->convert(
      'base' => 10,         # convert from base 16 to base 10
      'bit_group' => 8,     # octet grouping
      'delimiter' => '.'    # dot-delimited
    );
	# remove dots from mac address in decimal format
	$dec_mac =~ s/\.//go;
	# remove leading zeros from mac address in decimal format
	$dec_mac =~ s/^0+(?=[0-9])//;
	#print "1 mac $newMacaddr long $dec_mac\n";
    #$people->{$newMacaddr} = {"tracktype:PERSON","macAddress:".$newMacaddr,"trackid:SV1","tracknumber:".850,"longitude:".12.2542,"latitude:".41.79556,"heading:".0,"altitude:null","velocityx:".0,"velocityy:".0,"velocity:".0,"updatetime:".genDateTimeString(),"urno:null","flid:null","prefferedcallsign:SV1","droppedtrack:false"};
	$people->{$newMacaddr} = {};
	$people->{$newMacaddr}{"tracktype"} = "PEOPLE";
	$people->{$newMacaddr}{"macAddress"} = $newMacaddr;
	$people->{$newMacaddr}{"pathNumber"} = 1;
	$people->{$newMacaddr}{"trackid"} = "SV1";
	$people->{$newMacaddr}{"tracknumber"} = $dec_mac;
	$people->{$newMacaddr}{"longitude"} = "41.79533";
	$people->{$newMacaddr}{"latitude"} = "12.25422";
	$people->{$newMacaddr}{"heading"} = "0.0";
	$people->{$newMacaddr}{"altitude"} = "null";
	$people->{$newMacaddr}{"velocityx"} = "0.0";
	$people->{$newMacaddr}{"velocityy"} = "0.0";
	$people->{$newMacaddr}{"velocity"} = "0.0";
	$people->{$newMacaddr}{"updatetime"} = genDateTimeString();
	$people->{$newMacaddr}{"droppedtrack"} = "false";
	return $newMacaddr;
}

sub addPlane {
	my( $FlightNumber )=@_; 
	# {"tracktype":"AIRCRAFT","trackid":"JSA683","tracknumber":3531,"longitude":103.977646,"latitude":1.3492048,"heading":0.0,"altitude":1.75,"velocityx":-2.5,"velocityy":4.5,"velocity":5.147815,"updatetime":20220313073320,"urno":1831612125,"flid":"3K683","prefferedcallsign":null,"droppedtrack":false}
	$flights->{$FlightNumber} = {};
	$flights->{$FlightNumber}{"tracktype"} = "AIRCRAFT";
	$flights->{$FlightNumber}{"flightNumber"} = $FlightNumber;
	$flights->{$FlightNumber}{"flightstatus"} = "NONE";	
	$flights->{$FlightNumber}{"trackid"} = "JSA683";
	$flights->{$FlightNumber}{"tracknumber"} = 0;
	$flights->{$FlightNumber}{"longitude"} = "41.79533";
	$flights->{$FlightNumber}{"latitude"} = "12.25422";
	$flights->{$FlightNumber}{"heading"} = "".myRandomize($startingHeading)*(-1)."";
	$flights->{$FlightNumber}{"altitude"} = "null";
	$flights->{$FlightNumber}{"velocityx"} = "0.0";
	$flights->{$FlightNumber}{"velocityy"} = "0.0";
	$flights->{$FlightNumber}{"velocity"} = "0.0";
	$flights->{$FlightNumber}{"updatetime"} = genDateTimeString();
	$flights->{$FlightNumber}{"urno"} = "1831612125";
	$flights->{$FlightNumber}{"flid"} = "3K683";
	$flights->{$FlightNumber}{"prefferedcallsign"} = "null";
	$flights->{$FlightNumber}{"droppedtrack"} = "false";
}

sub addVehicule {
	my( $vehiculeNumber )=@_; 
	# {"tracktype":"VEHICLE","trackid":"SV1","tracknumber":850,"longitude":103.98325,"latitude":1.3701689,"heading":0.0,"altitude":null,"velocityx":0.0,"velocityy":0.0,"velocity":0.0,"updatetime":20220313073320,"urno":null,"flid":null,"prefferedcallsign":"SV1","droppedtrack":false}
	$vehicules->{$vehiculeNumber} = {};
	$vehicules->{$vehiculeNumber}{"tracktype"} = "VEHICLE";
	$vehicules->{$vehiculeNumber}{"vehiculenumber"} = $vehiculeNumber;
	$vehicules->{$vehiculeNumber}{"trackid"} = "SV1";
	$vehicules->{$vehiculeNumber}{"tracknumber"} = 0;
	$vehicules->{$vehiculeNumber}{"longitude"} = "41.79533";
	$vehicules->{$vehiculeNumber}{"latitude"} = "12.25422";
	$vehicules->{$vehiculeNumber}{"heading"} = "".myRandomize($startingHeading)*(-1)."";
	$vehicules->{$vehiculeNumber}{"velocityx"} = "0.0";
	$vehicules->{$vehiculeNumber}{"velocityy"} = "0.0";
	$vehicules->{$vehiculeNumber}{"velocity"} = "0.0";
	$vehicules->{$vehiculeNumber}{"updatetime"} = genDateTimeString();
	$vehicules->{$vehiculeNumber}{"droppedtrack"} = "false";
}

sub myRandomize {
	my( $numberMaxToRandomize )=@_; 
	$rndReturn = int(rand($numberMaxToRandomize))+1;
	#print "rand value for max $numberMaxToRandomize = $rndReturn\n";
	return $rndReturn;
}

sub genMacAddress {
	for ($i=00;$i<12;$i++){@m[$i]=int(rand(256));}
	$newmac = sprintf "%02X:%02X:%02X:%02X:%02X:%02X",@m;
	return $newmac;
}

sub genDateTimeString {
	# Assigning values to variables 
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(); 
	$myear = strftime "%Y", localtime;
    # Formatting the time representation 
    return sprintf("%04d%02d%02d%02d%02d%02d",$myear,$mon+1,$mday, $hour, $min, $sec);
}

sub publishPersonNewPosition {
	my( $chosenPersonMacAddress  )=@_;   
    $messageToPublish = "{\"tracktype\":\"".$people->{$chosenPersonMacAddress}{"tracktype"}."\",\"macAddress\":\"".$people->{$chosenPersonMacAddress}{"macAddress"}."\",\"trackid\":\"".$people->{$chosenPersonMacAddress}{"trackid"}."\",\"tracknumber\":".$people->{$chosenPersonMacAddress}{"tracknumber"}.",\"longitude\":".$people->{$chosenPersonMacAddress}{"longitude"}.",\"latitude\":".$people->{$chosenPersonMacAddress}{"latitude"}.",\"heading\":".$people->{$chosenPersonMacAddress}{"heading"}.",\"velocityx\":".$people->{$chosenPersonMacAddress}{"velocityx"}.",\"velocityy\":".$people->{$chosenPersonMacAddress}{"velocityy"}.",\"velocity\":".$people->{$chosenPersonMacAddress}{"velocity"}.",\"updatetime\":".genDateTimeString().",\"droppedtrack\":".$people->{$chosenPersonMacAddress}{"droppedtrack"}."}";
	$mqtt->publish($destinationTopicPrefix."/".$people->{$chosenPersonMacAddress}{"tracktype"}."/".$people->{$chosenPersonMacAddress}{"macAddress"}."/".$people->{$chosenPersonMacAddress}{"latitude"}."/".$people->{$chosenPersonMacAddress}{"longitude"}, $messageToPublish);
}

sub publishPlaneNewPosition {
	# {"tracktype":"AIRCRAFT","trackid":"JSA683","tracknumber":3531,"longitude":103.977646,"latitude":1.3492048,"heading":0.0,"altitude":1.75,"velocityx":-2.5,"velocityy":4.5,"velocity":5.147815,"updatetime":20220313073320,"urno":1831612125,"flid":"3K683","prefferedcallsign":null,"droppedtrack":false}
	my( $FlightNumber,$heading  )=@_;   
	$shiftedTrackNum = $flights->{$FlightNumber}{"flightNumber"}*10;   
    $messageToPublish = "{\"tracktype\":\"".$flights->{$FlightNumber}{"tracktype"}."\",\"flightNumber\":\"".$flights->{$FlightNumber}{"flightNumber"}."\",\"flightstatus\":\"".$flights->{$FlightNumber}{"flightstatus"}."\",\"trackid\":\"".$flights->{$FlightNumber}{"trackid"}."\",\"tracknumber\":\"".$shiftedTrackNum."\",\"longitude\":".$flights->{$FlightNumber}{"longitude"}.",\"latitude\":".$flights->{$FlightNumber}{"latitude"}.",\"heading\":".$heading.",\"altitude\":".$flights->{$FlightNumber}{"altitude"}.",\"velocityx\":".$flights->{$FlightNumber}{"velocityx"}.",\"velocityy\":".$flights->{$FlightNumber}{"velocityy"}.",\"velocity\":".$flights->{$FlightNumber}{"velocity"}.",\"updatetime\":".genDateTimeString().",\"urno\":".$flights->{$FlightNumber}{"urno"}.",\"flid\":\"".$flights->{$FlightNumber}{"flid"}."\",\"prefferedcallsign\":\"".$flights->{$FlightNumber}{"prefferedcallsign"}."\",\"droppedtrack\":".$flights->{$FlightNumber}{"droppedtrack"}."}";
	
	#build destination topic
	$topicDest = $destinationTopicPrefix."/".$flights->{$FlightNumber}{"tracktype"}."/".$shiftedTrackNum."/".$flights->{$FlightNumber}{"latitude"}."/".$flights->{$FlightNumber}{"longitude"};
	#print "dest topic: $topicDest\n";
	
	$mqtt->publish($topicDest, $messageToPublish);
}

sub publishVehiculeNewPosition {
	# {"tracktype":"VEHICLE","trackid":"SV1","tracknumber":850,"longitude":103.98325,"latitude":1.3701689,"heading":0.0,"altitude":null,"velocityx":0.0,"velocityy":0.0,"velocity":0.0,"updatetime":20220313073320,"urno":null,"flid":null,"prefferedcallsign":"SV1","droppedtrack":false}
	my( $vehiculeNumber,$heading  )=@_;   
	$shiftedTrackNum = $vehicules->{$vehiculeNumber}{"vehiculenumber"}*100;
    $messageToPublish = "{\"tracktype\":\"".$vehicules->{$vehiculeNumber}{"tracktype"}."\",\"vehiculenumber\":\"".$vehicules->{$vehiculeNumber}{"vehiculenumber"}."\",\"trackid\":\"".$vehicules->{$vehiculeNumber}{"trackid"}."\",\"tracknumber\":\"".$shiftedTrackNum."\",\"longitude\":".$vehicules->{$vehiculeNumber}{"longitude"}.",\"latitude\":".$vehicules->{$vehiculeNumber}{"latitude"}.",\"heading\":".$heading.",\"velocityx\":".$vehicules->{$vehiculeNumber}{"velocityx"}.",\"velocityy\":".$vehicules->{$vehiculeNumber}{"velocityy"}.",\"velocity\":".$vehicules->{$vehiculeNumber}{"velocity"}.",\"updatetime\":".genDateTimeString().",\"droppedtrack\":".$vehicules->{$vehiculeNumber}{"droppedtrack"}."}";
	$mqtt->publish($destinationTopicPrefix."/".$vehicules->{$vehiculeNumber}{"tracktype"}."/".$shiftedTrackNum."/".$vehicules->{$vehiculeNumber}{"latitude"}."/".$vehicules->{$vehiculeNumber}{"longitude"}, $messageToPublish);
}

sub walkPersonAlongRandomPath {
	my( $personMacAddress )=@_;   
	# assign a random path to that person
	$randomPathNumber = myRandomize($numberOfLineStrings);
	$randomPathIndex = $randomPathNumber-1;
	#count the coordinates for that random path
    for (@walkCoordArrayFinal[$randomPathIndex]){
		$numberOfCoordinates = scalar(@$_), "\n"; 	
	}
	print "random Chosen path $randomPathNumber for person $personMacAddress between $numberOfLineStrings paths that includes $numberOfCoordinates coordinates\n";
	# walk a person along a random walking path
	for (my $y=0; $y < $numberOfCoordinates ; $y++) {
		# randomly stop walking
		$y-- if ((myRandomize(2)-1) == 1);
		$randLatShift = myRandomize(2)/10000000;
		$randLonShift = myRandomize(2)/10000000;
		$people->{$personMacAddress}{"longitude"} = $walkCoordArrayFinal[$randomPathIndex][$y][0]+$randLatShift;
		$people->{$personMacAddress}{"latitude"} = $walkCoordArrayFinal[$randomPathIndex][$y][1]+$randLonShift;
		publishPersonNewPosition($personMacAddress);
		print "person with mac address ".$personMacAddress." moved in path number $randomPathNumber to longitude ".$walkCoordArrayFinal[$randomPathIndex][$y][0]." and latitude ".$walkCoordArrayFinal[$randomPathIndex][$y][1]."\n";		
		# slow down movement by randomize waits between every move
		sleep(myRandomize(3));		
	}
}

sub movePlaneAlongTaxiPath {
	my( $FlightNumber, $PathNumber )=@_;

	#check if we should skip this path to minimize planes on track
	$skipPath = myRandomize(2);
	return  if($skipPath eq 1);
	
	$PathIndex = $PathNumber-1;
	#count the coordinates for that random path
    for (@walkCoordArrayFinal[$PathIndex]){
		$numberOfCoordinates = scalar(@$_), "\n"; 	
	}
	print "random Chosen path $PathNumber for Plane Flight number $FlightNumber between $numberOfLineStrings paths that includes $numberOfCoordinates coordinates\n";
	# if =2 reverse the path ( 0 or 2) runway to parking <-> (1) parking to runway)
	$reversePath = myRandomize(2);
	if ($reversePath eq 1){
		$startIndex = 0;
		$endIndex = $numberOfCoordinates;
		$fstatus = "TAXINGTORUNWAY";
	}
	else{
		$startIndex = ($numberOfCoordinates-1)*(-1);
		$endIndex = 1;
		$fstatus = "TAXINGTOGATE";
	}
	# move a plane along a random plane path
	for (my $y=$startIndex; $y < $endIndex ; $y++) {
		$randLatShift = 0; #myRandomize(2)/100000000;
		$randLonShift = 0; #myRandomize(2)/100000000;
		$flights->{$FlightNumber}{"latitude"} = $walkCoordArrayFinal[$PathIndex][abs($y)][1]+$randLonShift;
		$flights->{$FlightNumber}{"longitude"} = $walkCoordArrayFinal[$PathIndex][abs($y)][0]+$randLatShift;
		$flights->{$FlightNumber}{"flightstatus"} = $fstatus;
		# keep previous heading
		$headingFromVector = $flights->{$FlightNumber}{"heading"};
		# new heading is calculated with vector (coords before move, coords after move) if has not reached end of coordinates array
		if ($y < ($endIndex-1)){
			$headingFromVector = calcHeading($flights->{$FlightNumber}{"latitude"},$flights->{$FlightNumber}{"longitude"},$walkCoordArrayFinal[$PathIndex][abs($y+1)][1],$walkCoordArrayFinal[$PathIndex][abs($y+1)][0])+130;
		}
		publishPlaneNewPosition($FlightNumber,$headingFromVector);
		# if starting from parking wait a little at parking space before going to runway or
		# if starting from runway wait a little at parking space before disappearing 		
		print "plane $FlightNumber $fstatus with flight number ".$FlightNumber.", heading $headingFromVector moved (along path number $PathNumber) to longitude ".$walkCoordArrayFinal[$PathIndex][abs($y)][0]." and latitude ".$walkCoordArrayFinal[$PathIndex][abs($y)][1]."\n";		
		# wait at gate when taxing to runway
		sleep($planeWaitTimeAtGate+myRandomize(5)) if (($y eq $startIndex) and ($reversePath eq 1));
		# wait at gate when taxing from runway
		sleep($planeWaitTimeAtGate+myRandomize(5)) if (($y eq $endIndex-1) and !($reversePath eq 1));
		# slow down movement by randomize waits between every move
		sleep(myRandomize(10));
		
	}
}

sub movePlaneAlongRunwayPath {
	my( $FlightNumber )=@_;   
	# assign a random path to that person
	$randomPathNumber = myRandomize($numberOfLineStrings);
	$randomPathIndex = $randomPathNumber-1;
	#count the coordinates for that random path
    for (@walkCoordArrayFinal[$randomPathIndex]){
		$numberOfCoordinates = scalar(@$_), "\n"; 	
	}
	print "random Chosen path $randomPathNumber for Plane Flight number $FlightNumber between $numberOfLineStrings paths that includes $numberOfCoordinates coordinates\n";
	# if =2 or 0 reverse the path (landing vs take off)
	$reversePath = myRandomize(2);
	if ($reversePath eq 1){
		$startIndex = 0;
		$endIndex = $numberOfCoordinates;
		$fstatus = "TAKINGOFF";
	}
	else{
		$startIndex = ($numberOfCoordinates-1)*(-1);
		$endIndex = 1;
		$fstatus = "LANDING";
	}
	# move a plane along a random plane path
	for (my $y=$startIndex; $y < $endIndex ; $y++) {
		# randomly stop walking
		#$y-- if ((myRandomize(2)-1) == 1);
		$randLatShift = 0; #myRandomize(2)/100000000;
		$randLonShift = 0; #myRandomize(2)/100000000;
		$flights->{$FlightNumber}{"latitude"} = $walkCoordArrayFinal[$randomPathIndex][abs($y)][1]+$randLonShift;
		$flights->{$FlightNumber}{"longitude"} = $walkCoordArrayFinal[$randomPathIndex][abs($y)][0]+$randLatShift;
		$flights->{$FlightNumber}{"flightstatus"} = $fstatus;
		# keep previous heading
		$headingFromVector = $flights->{$FlightNumber}{"heading"};
		# new heading is calculated with vector (coords before move, coords after move) if has not reached end of coordinates array
		if ($y < ($numberOfCoordinates-1)){
			$headingFromVector = calcHeading($flights->{$FlightNumber}{"latitude"},$flights->{$FlightNumber}{"longitude"},$walkCoordArrayFinal[$randomPathIndex][abs($y+1)][1],$walkCoordArrayFinal[$randomPathIndex][abs($y+1)][0])+130;
		}
		publishPlaneNewPosition($FlightNumber,$headingFromVector);
		#print "plane taking off" if ($reversePath eq 1);
		#print "plane landing" if !($reversePath eq 1);
		print "plane $FlightNumber $fstatus with flight number ".$FlightNumber.", heading $headingFromVector moved (along path number $randomPathNumber) to longitude ".$walkCoordArrayFinal[$randomPathIndex][abs($y)][0]." and latitude ".$walkCoordArrayFinal[$randomPathIndex][abs($y)][1]."\n";		
		Time::HiRes::sleep(0.6); #.x seconds
	}
	# make plane 'disapear'from map
	$flights->{$FlightNumber}{"latitude"} = 0;
	$flights->{$FlightNumber}{"longitude"} = 0;
	publishPlaneNewPosition($FlightNumber,0);
}

sub moveVehiculeAlongPath {
	my( $vehiculeNumber, $PathNumber )=@_;

	#check if we should skip this path to minimize vehicules on track
	$skipPath = myRandomize(2);
	return  if($skipPath eq 1);
	
	$PathIndex = $PathNumber-1;
	#count the coordinates for that random path
    for (@walkCoordArrayFinal[$PathIndex]){
		$numberOfCoordinates = scalar(@$_), "\n"; 		
	}
	print "random Chosen path $PathNumber for vehicule number $vehiculeNumber between $numberOfLineStrings paths that includes $numberOfCoordinates coordinates\n";
	# reverse the path ( 0 or 2) source to destination <-> (1) destination to source)
	$reversePath = myRandomize(2);
	if ($reversePath eq 1){
		$startIndex = 0;
		$endIndex = $numberOfCoordinates;
	}
	else{
		$startIndex = ($numberOfCoordinates-1)*(-1);
		$endIndex = 1;
	}
	# move a vehicule along a random vehicule path
	for (my $y=$startIndex; $y < $endIndex ; $y++) {
		$randLatShift = 0; #myRandomize(2)/100000000;
		$randLonShift = 0; #myRandomize(2)/100000000;
		$vehicules->{$vehiculeNumber}{"latitude"} = $walkCoordArrayFinal[$PathIndex][abs($y)][1]+$randLonShift;
		$vehicules->{$vehiculeNumber}{"longitude"} = $walkCoordArrayFinal[$PathIndex][abs($y)][0]+$randLatShift;
		# keep previous heading
		$headingFromVector = $vehicules->{$vehiculeNumber}{"heading"};
		# new heading is calculated with vector (coords before move, coords after move) if has not reached end of coordinates array
		if ($y < ($endIndex-1)){
			$headingFromVector = calcHeading($vehicules->{$vehiculeNumber}{"latitude"},$vehicules->{$vehiculeNumber}{"longitude"},$walkCoordArrayFinal[$PathIndex][abs($y+1)][1],$walkCoordArrayFinal[$PathIndex][abs($y+1)][0])+130;
		}
		publishVehiculeNewPosition($vehiculeNumber,$headingFromVector);
		print "vehicule with number ".$vehiculeNumber.", heading $headingFromVector moved (along path number $PathNumber) to longitude ".$walkCoordArrayFinal[$PathIndex][abs($y)][0]." and latitude ".$walkCoordArrayFinal[$PathIndex][abs($y)][1]."\n";		
		sleep(myRandomize(6));
		
	}
}

$countPolygons = 0;
my $readingFilehandle;
my $startofPolygonList = 0;

# read input file (maps vector path export)

if ($geolocationType eq 'GEOFENCEONLY'){ 
	# in geofencing only multiple input files
    print "\n\n//#########################################################################\n";
    print "//################# GEOLOCATION POLYGON CODE GENERATOR ####################\n";
    print "//##################### SOLACE CORPORATION 2025 #############################\n";
    print "//#########################################################################\n\n";
}
else
{
	# NON geofencing only one input file
	$fileHandleArray[0] = IN;
}

## for every file handle in input (only one if not geofencing only)
#for $readingFilehandle (@fileHandleArray)
foreach $loopCount (0..($numParameters/2))
   {
	#print "		\/\/iteration file $loopCount\n";
	$startofPolygonList = 1 if ($geolocationType eq 'GEOFENCEONLY');
	$currentFileHandle = $fileHandleArray[$loopCount];
	while (<$currentFileHandle>) {	
		if ($geolocationType eq 'GEOFENCEONLY'){
			# skip first array element because empty in geofencing only
			#print "before read $loopCount\n";
			if ($loopCount == 0) {$loopCount++; print "skipped file $loopCount\n"; next;}
			#print "starting read from file $loopCount\n";
		}
		else {
			# do only first handle (0) if not geofencing only
			last if ($loopCount == 1);		
		}
	   $row = $_;
	   #print "read row: $row\n";
	   #only read LINESTRINGS
	   #next if (!(/^\"LINESTRING\s.*\((.*)\).*/o));
	   #if is a google defined area / polygon
	   if ((/^\"POLYGON\s.*\(\((.*)\)\)\"\,(.*)/o)){
		   #print geofencing code only if asked
		   if ($geolocationType eq 'GEOFENCEONLY'){ 
			   $countPolygons++;
			   $PolygonString = $1;
			   $PolygonName = $2;
			   # remove trailing ','
			   $PolygonName =~ s/\,//go;
			   #print "POLIGON FOUND \'$PolygonString\'\n\n";
			   @polyCoordArray = split ",",$PolygonString;

			   # print javascript code for polygons --------------------------------------
			   # function declaration only for first iteration of polygon list
			   print " function addNewPolyCoords(coords,polyType) {\n" if (($loopCount == 1) and ($countPolygons == 1));
			   if ($startofPolygonList == 1) {
					print "		if (polyType == \"$geofenceTags[$loopCount]\"){\n";
					$startofPolygonList = 0;
			   }
			   print "	  	coords$countPolygons = [";
			   for (my $w=0; $w < @polyCoordArray; $w++) {
					#print "\n$i $walkCoordArray[$i]";
					$polyCoordCouple = $polyCoordArray[$w];
					@polyCoordCoupleArray = split " ",$polyCoordCouple;
					#$polyCoordArrayFinal[$numberOfLineStrings][$i][0] = $polyCoordCoupleArray[0];
					#$polyCoordArrayFinal[$numberOfLineStrings][$i][1] = $polyCoordCoupleArray[1];
					print "	new google.maps.LatLng($polyCoordCoupleArray[1],$polyCoordCoupleArray[0]), ";
					#print "\n\n$i lat->$walkCoordArrayFinal[$numberOfLineStrings][$i][0]";
					#print "\n\n$i long->$walkCoordArrayFinal[$numberOfLineStrings][$i][1]";
					}
				print "	];\n\n";
				print "		var poly$countPolygons = new google.maps.Polygon({\n";
				print "		map: map,\n";
				print "		paths: coords$countPolygons,\n";
				print "		strokeColor: shapeColor,\n";
				print "		strokeOpacity: 0.7,\n";
				print "		strokeWeight: 3,\n";
				print "		fillColor: shapeColor,\n";
				print "		fillOpacity: 0,//0.025,\n";
				print "		visible: true,\n";
				print "		draggable: true,\n";
				print "		clickable: true,\n";
				print "		editable: true,\n";
				print "		geodesic: false,\n";
				print "		zIndex: 200000,\n";
				print "  		});\n";
				print "  		searchShapes[\"poly\"].push(poly$countPolygons);\n";
				print "  		totalSearchShapes++;\n";
				print "  		SearchShapesNames[totalSearchShapes] = \"$PolygonName\";\n";
				print "  		google.maps.event.addListener(poly$countPolygons.getPath(), 'set_at', updateSearch);\n";
				print "  		google.maps.event.addListener(poly$countPolygons.getPath(), 'insert_at', updateSearch);\n";
				print "  		google.maps.event.addListener(poly$countPolygons.getPath(), 'remove_at', updateSearch);\n";
				print "  		google.maps.event.addListener(poly$countPolygons, 'dragstart', startDrag);\n";
				print "  		google.maps.event.addListener(poly$countPolygons, 'dragend', endDrag);\n\n";
			   # END OF print javascript code for polygons --------------------------------------
			   # exit here if only need to pring geofencing code		   
		   }
		}
	   #if is a google defined path
	   if ((/^\"LINESTRING\s.*\((.*)\).*/o)){
		   $coordString = $1;
		   #print "\n\n$coordString";
		   @walkCoordArray = split ",",$coordString;
		   
		   # Build coord Array from google maps export vector walkpath coordinates array and store it into $walkCoordArrayFinal[pathNumber][coordNumber][lat=0|long=1]
		   for (my $i=0; $i < @walkCoordArray; $i++) {
				#print "\n$i $walkCoordArray[$i]";
				$coordCouple = $walkCoordArray[$i];
				@coordCoupleArray = split " ",$coordCouple;
				$walkCoordArrayFinal[$numberOfLineStrings][$i][0] = $coordCoupleArray[0];
				$walkCoordArrayFinal[$numberOfLineStrings][$i][1] = $coordCoupleArray[1];
				#print "\n\n$i lat->$walkCoordArrayFinal[$numberOfLineStrings][$i][0]";
				#print "\n\n$i long->$walkCoordArrayFinal[$numberOfLineStrings][$i][1]";
				}
			#count the linestrings paths found in file
			$numberOfLineStrings++;
		   }
	   }
	#$loopCount++;
	if (($geolocationType eq 'GEOFENCEONLY') and  ($countPolygons > 0)){
		print "  	}\n\n";
		}
   } 
   print "}\n\n" if ($geolocationType eq 'GEOFENCEONLY'); 
die "\n\n\n\n//... done Geofencing code generation, Exiting!\n\n" if ($geolocationType eq 'GEOFENCEONLY');
 

if ($geolocationType eq 'PEOPLE') {
	# add a record of a new person
	$newPersonMacAddress = addPerson();
	print "new person with mac address $newPersonMacAddress\n";
	# walk that person along a random walkpath
	walkPersonAlongRandomPath($newPersonMacAddress);
}
elsif($geolocationType eq 'AIRCRAFT'){
	# add a record of a new plane
	addPlane($newPlaneflightNumber);
	print "new Plane with flight number $newPlaneflightNumber\n";
	# move plane along a random flight path. Note: we use flight number also to indentify path
	if ($aircraftMovementType eq 'TAXIING') {
		movePlaneAlongTaxiPath($newPlaneflightNumber,$newPlaneflightNumber);
	}
	elsif ($aircraftMovementType eq 'RUNWAY'){
		movePlaneAlongRunwayPath($newPlaneflightNumber);
	}
}
elsif($geolocationType eq 'VEHICLE'){
	# add a record of a new vehicule
	addVehicule($newVehiculeNumber);
	print "new Vehicle with number $newVehiculeNumber\n";
	# move vehicule along a random drive path. Note: we use vehicule number also to indentify path
	moveVehiculeAlongPath($newVehiculeNumber,$newVehiculeNumber);	
}

if (!($geolocationType eq 'GEOFENCEONLY')){ 
	$mqtt->disconnect();
	print "MQTT broker disconnected! \n";
}
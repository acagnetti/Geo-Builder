# Command line arguments: <SMFHOST> <VPNNAME> <MQTTHOST> <USER> <PASSWORD> <PEOPLENUMBER> <WALKPATHFILE> <PLANETAXINUMBER> <PLANETAXIPATHFILE> <PLANETAKEOFFNUMBER> <PLANETAKEOFFPATHFILE> <VEHICLENUMBER> <VEHICLEPATHFILE>
# Command line GEOFENCING CODE GENERATOR (max 10 files): [GEOFENCEONLY] <GEOFENCETAG1> <GEOFILE1> <GEOFENCETAG2> <GEOFILE2> <GEOFENCETAG3> <GEOFILE3> <GEOFENCETAG4> <GEOFILE4> <GEOFENCETAG5> <GEOFILE5> <GEOFENCETAG6> <GEOFILE6> <GEOFENCETAG7> <GEOFILE7> <GEOFENCETAG8> <GEOFILE8> <GEOFENCETAG9> <GEOFILE9> <GEOFENCETAG10> <GEOFILE10> 
# Start fence detection
#echo "kiosk Command line $1 $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13}" 

if [[ "$1" == "GEOFENCEONLY" ]]
then # only generate geofence code
		perl generateGeolocationEvents.pl GEOFENCEONLY $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13} ${14} ${15} ${16} ${17} ${18} ${19} ${20}
elif [[ "$1" == "GEOFENCEBUTTONSONLY" ]]
then # only generate geofence button panel code
		perl generateGeolocationEvents.pl GEOFENCEBUTTONSONLY $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13} ${14} ${15} ${16} ${17} ${18} ${19} ${20}
else # run the full geo events generator with fence detection process
		nohup java -cp ./target/CAGFence-0.0.1-SNAPSHOT-jar-with-dependencies.jar CAGFence $1 $4@$2 $5 &
		#endless loop to generate geo events for all objects
		while true
		do
		  rm nohup.out;
		  ./launchGeneric.sh $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13};
		  sleep 30; 
		done
fi

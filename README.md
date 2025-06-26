# Solace Geo-Builder

![image](https://github.com/user-attachments/assets/1550a6f7-ad20-4453-b257-b2b3e6425c8f)

![image](https://github.com/user-attachments/assets/36af231d-2610-451f-8fe7-d8af6e7a2a12)

**Description**

This framework allows to simulate / manage Geolocation events about People walking, moving vehicles, airplane taxiing and taking off/ landing... or pretty much anything that moves and produces events by Using an **Event driven Architecture**. There is also a html/javascript client to visualize events on a google map. This work is easily usable to represent geo events anywhere in the world

It can be used to: 
* simulate / generate geo location events
* publish (**liberate**) these events to a Solace Event Broker
* visualize these events on a Google Maps with moving icons
* enable **democratize** of geo location events to any applications with Solace Native Multi protocol capabilities 
* support polygons for fence detection to detect object entering a geographical 'zone' and **react** creating events back to the Solace broker


***Anybody*** can try generating / visualizing / consuming geo location events with **geoBuilder** with 3 to 5 simple steps:
1. *[OPTIONAL]* if you do not have access to geo location events, you can design them by using the [Google Maps Designer](https://www.google.com/maps/about/mymaps/)
2. Set up a Solace broker (check the [try Solace page](https://solace.com/try-it-now/) for a free trial)
3. *[OPTIONAL]* run the geo location event generator to publish events to the Solace Broker
4. Use a HTML/javascript client template to visualize geo location events in a web browser
5. Leverage geographical Fences with Polygons designed in Google Maps Designer (step 1) to detect moving Objects entering a geographical zone and react by publishing new events to the Solace Broker

**INSTRUCTIONS**

In order to experience Geo Location Events you can use geoBuilder, A Solace Broker and a web browser
- *[OPTIONAL]* In case you do not have access to applications that generate geo location events, Google Maps Editor allow to create vector paths and polygons for geofences
  - Open [Google Maps Designer](https://www.google.com/maps/about/mymaps/)
  ![image](https://github.com/user-attachments/assets/d7d47e56-5184-4f4b-a86c-dcb8814e8d9a)
  - log in to the Editor
  ![image](https://github.com/user-attachments/assets/507ed8a3-e482-40bd-ae74-2d2ac987a4e2)  
  - Draw your vector path and polygonsin different 'levels' (eg. People, Vehicles, planes, polygons etc..)
  ![image](https://github.com/user-attachments/assets/cf72f3b1-1fbb-449a-a85c-6bf46025235c)
  - Export each vector path and polygons 'levels' to a separate csv file (eg. People, Vehicles, planes, shops, security zones etc..) in a directory (eg `/home/demo/adr1/googleGeoPath/pathfiles`)
  ![image](https://github.com/user-attachments/assets/be2358d3-5a92-4b53-9d21-a358ec1c0e48)


- Set up a Solace Broker (if you do not have access to an existing Solace broker)
  - go to [try Solace page](https://solace.com/try-it-now/) and choose betweem a Self Managed or Cloud Managed broker and follow insructions
  ![image](https://github.com/user-attachments/assets/9e609873-ced3-4b9a-84f1-d8b89378b0fc)

- *[OPTIONAL]* if you have designed you own vector path and polygons using the Google maps editor and exported them to csv you can run the geo location event generator
  - Build your docker container image of the geoBuilder geo locaion event Generator and fence detection engine: <BR>
    	- mirror the Github repo on your machine: `gh repo clone acagnetti/Geo-Builder` <BR>
        - go to main directory on local filesystem: `cd Geo-Builder` <BR>
    	- build docker image: `sudo docker build -f Dockerfile -t solace-geo-events-manager .`<BR>

  - generate HTML/Javascript code to visualize/activate level zones in the Google Map and save them in the `js/genPolygons.js` file: <BR>
    `sudo docker run --rm --name geoBuilder -v <googleMapsExportFilePath>:/usr/src/myapp/geofiles solace-geo-events-manager GEOFENCEONLY <GEOFENCETAG1> ./geofiles/<GeoFenceExportFile1> <GEOFENCETAG2> ./geofiles/<GeoFenceExportFile2> ... > js/genPolygons.js` <BR>

    *EXAMPLE* <BR>

     `sudo docker run --rm --name geoBuilder -v /mnt/d/Solace/Software/demo/Rome-Airport-ADR/adr1/googleGeoPath/pathfiles:/usr/src/myapp/geofiles solace-geo-events-manager GEOFENCEONLY SECURITY ./geofiles/walkpath10.csv TAXIING ./geofiles/planetaxipath.csv RUNWAY ./geofiles/planetakeoffpath.csv SHOP ./geofiles/shops.csv > js/genPolygons.js`

  - generate HTML/Javascript code to visualize the panel with buttons to activate the fence detection in the Google Map and save them in the `menu.html` file: <BR>
   ![image](https://github.com/user-attachments/assets/141c16e9-72d8-42df-bcd8-af68488437f1)

    `sudo docker run --rm --name geoBuilder -v <googleMapsExportFilePath>:/usr/src/myapp/geofiles solace-geo-events-manager GEOFENCEBUTTONSONLY <GEOFENCETAG1> ./geofiles/<GeoFenceExportFile1> <GEOFENCETAG2> ./geofiles/<GeoFenceExportFile2> ... > menu.html`

    *EXAMPLE* <BR>

     `sudo docker run --rm --name geoBuilder -v /mnt/d/Solace/Software/demo/Rome-Airport-ADR/adr1/googleGeoPath/pathfiles:/usr/src/myapp/geofiles solace-geo-events-manager GEOFENCEBUTTONSONLY SECURITY ./geofiles/walkpath10.csv TAXIING ./geofiles/planetaxipath.csv RUNWAY ./geofiles/planetakeoffpath.csv SHOP ./geofiles/shops.csv > menu.html`
    
  - run the docker container (use the google maps file export path set above and the file names given when exporting the map levels, make sure you change the values between <>):
    
      `sudo docker run --rm -v <googleMapsExportFilePath>:/usr/src/myapp/geofiles --name geoBuilder solace-geo-events-manager
       <tcps://SMFSolaceBrokerURL:SMFsolaceBrokerPort> <solaceBrokerVPNName> <MQTTsolaceBrokerURL:MQTTsolaceBrokerPort> <solaceUSer>
       <solacePassword> <numberOfPeople> <peopleWalkingFileName> <numberOfPlanesTaxiing> <planesTaxiingFileName> <numberOfPlanesTakingOff>
       <planesTakingOffFileName> <numberOfVehicles> <VehiclesFileName>` 

       ***[EXAMPLE to run the generator for 10 people walking, 10 planes taxiing to runway, 5 planes taking off, 10 vehicles driving ]***

       *`sudo docker run --rm -v /home/demo/adr1/googleGeoPath/pathfiles:/usr/src/myapp/geofiles --name geoBuilder solace-geo-events-manager
       tcps://mr-connection-xxxyyyzzz.messaging.solace.cloud:55443 myvpn mr-connection-xxxyyyzzz.messaging.solace.cloud:1883 uuuuuuuuuuuuuu
       ppppppppppppppppp 20 walkpath10.csv 10 planetaxipath.csv 5 planetakeoffpath.csv 10 vehiclePath.csv`*

- Download the web page client to visualize the events in a web browser and configure it to connect to your Solace Broker
  - setup a web server (example NGINX)
  - copy the template web page client to the web server home page directory (done with clone repo step above) and configure Geo-Builder directory as home for NGINX web page
  - configure the Solace connection parameters in the *`index.html`* page and *`js/auth.js`*
      	- edit file parameters with the right values:
   		`<YOUR_GOOGLE_MAPS_KEY> <YOUR_SOLACE_USER> <YOUR_SOLACE_PASSWORD> <YOUR_SOLACE_VPN> <YOUR_SOLACE_URL>`
		

      *EXAMPLE* <BR>

       `<script src="https://maps.googleapis.com/maps/api/js?key=nkvdwbWA8CuZWFMjQRQVMkrDgtguRNTAkjs5s&v=beta&libraries=visualization"></script>` <BR>
    	`mySessionProperties.userName = "myuser"; // Solace user` <BR>
    	`namySessionProperties.password = "mypassword";  // Solace password` <BR>
    	`mySessionProperties.vpnName = "myvpn"; // Solace VPN` <BR>
    	`mySessionProperties.url = "wss://mr-connection-xxxxxxxxxx.messaging.solace.cloud:443";  // Solace URL` <BR>

  - Open your browser and open your geo Events page hosted in your web browser.
    Topics used for this framework:
    - `geo/situation/track/v1/{trackType}/{trackNum}/{lat}/{lon}` this is used to publish geo location events with coordinate (eg. *geo/situation/track/v1/VEHICLE/100/41.7955198/12.2495002*)<BR>
    - `geo/situation/fence/v1/request` this is a new/delete fence request sent from js client to add or remove fences to fence detection<BR>
    - `geo/situation/fence/v1/alert/{tracktype}/{tracknumber}/{geofenceName}/latitude/longitude` this is an alert message from the the fence detection process that something has entered that fence<BR>
    ![image](https://github.com/user-attachments/assets/9c75f615-0d19-486d-8cc9-662c09dfe2b0) <BR>

- when done, remember to stop the docker container: `sudo docker stop geoBuilder`<BR>

  **ENJOY!**

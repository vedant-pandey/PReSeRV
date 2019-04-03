import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
          body: FireMap(),
      )
    );
  }
}

class FireMap extends StatefulWidget {
  @override
  State createState() => FireMapState();
}


class FireMapState extends State<FireMap> {
  GoogleMapController mapController;
  Location location=new Location();

  build(context) {
    return Stack(children: <Widget>[
      GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(24.142, -110.321),
          zoom:15
        ),
        onMapCreated: _onMapCreated,
        myLocationEnabled: true,
        trackCameraPosition: true,
      ),
      Positioned(
        bottom: 50,
        right: 10,
        child: 
          FlatButton(
            child: Icon(Icons.pin_drop,color: Colors.white),
            color: Colors.green,
            onPressed:  _addMarker
          ),
      )
    ]);
  }

  void _onMapCreated(GoogleMapController controller){
    setState(() {
      mapController=controller;
    });
  }

  _addMarker(){
    var marker = MarkerOptions(
      position: mapController.cameraPosition.target,
      icon: BitmapDescriptor.hueViolet,
      infoWindowText: InfoWindowText('Magic Marker', '🍄🍄🍄')
    );

    mapController.addMarker(marker);
  }

  _animateToUser() async {
    var pos = await location.getLocation();

    mapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(pos['latitude'], pos['longitude']),
        zoom: 17.0,
        )
      )
    );
  }

}
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
// import 'package:geolocator/geolocator.dart';

void main() => runApp(
  MaterialApp(
    home: Scaffold(
      body:PermissionPage()
      )
    )
  );

class PermissionPage extends StatefulWidget{
  @override
  _PermissionPageState createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> with WidgetsBindingObserver {
  GoogleMapController mapController;
  Location location=new Location();
  PermissionStatus _status;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PermissionHandler()
      .checkPermissionStatus(PermissionGroup.locationWhenInUse)
      .then(_updateStatus);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if (state ==AppLifecycleState.resumed) {
      PermissionHandler()
        .checkPermissionStatus(PermissionGroup.locationWhenInUse)
        .then(_updateStatus);
    }
  }

  @override
  Widget build(BuildContext context){
    return SafeArea(child: Column(
      children: <Widget>[
        Text('$_status'),
        SizedBox(height: 60),
        RaisedButton(child: Text('Ask Permission'),onPressed: _askPermission,)
      ],
    ));
  }

  void _updateStatus(PermissionStatus status){
    if (status !=_status) {
      setState((){
        _status=status;
      });
    }
    if (status == PermissionStatus.granted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MyApp())
      );
    }
  }

  void _askPermission() {
    PermissionHandler().requestPermissions([PermissionGroup.locationWhenInUse])
    .then(_onStatusRequested);
  }
  
  void _onStatusRequested(Map<PermissionGroup, PermissionStatus> statuses){
    final status =statuses[PermissionGroup.locationWhenInUse];
    if (status !=PermissionStatus.granted){
      PermissionHandler().openAppSettings();
    } else{
    _updateStatus(status);
    }
  }
}






////////////////////////////////////////////////////////////////////////////////////

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
  Location location = new Location();
  http.Response response;
  String disp='Please click the play button to get the speed';

  @override
  void initState(){
    super.initState();
    // _getStatus();
  }

  // void _getStatus() async {
  //   geolocationStatus = await Geolocator().checkGeolocationPermissionStatus();
  //   print(geolocationStatus);
  // }

  build(context) {
    // location.getLocation().then(onValue)
    return Stack(children: <Widget>[
      GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(26.886309837213254, 81.05897828936577),
          zoom:35
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
      ),
      Positioned(
        bottom: 50,
        left: 10,
        child: 
          FlatButton(
            child: Icon(Icons.play_circle_outline,color: Colors.white),
            color: Colors.blue,
            onPressed:  getSpeed
          ),
      ),
      Positioned(
        top: 50,
        right: 10,
        height: 55,
        width:140,
        child: 
          Card(
            child: Text(
              disp,
              textAlign:TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto'
              ),
            ),
            elevation: 20,
      ),
      )
    ]);
  }

  void getSpeed() async {
    var position=mapController.cameraPosition.target;
    // print(position.latitude);
    // print(position.longitude);
    String la1=position.latitude.toString();
    String la2=(position.latitude+0.00001).toString();
    String la3=(position.latitude+0.00002).toString();
    String lo1=position.longitude.toString();
    String lo2=(position.longitude+0.00001).toString();
    String lo3=(position.longitude+0.00002).toString();
    String param='path='+la1+','+lo1+'|'+la2+','+lo2+'|'+la3+','+lo3;
    String t='AIzaSyAZHZCliFwEcm6AlLeRuctFCqIY-aBGaGE';
    String t2='AIzaSyCZSwJSBuEa7EfBHqBAaYkEy-tbOKdHOa4';
    String uri = 'https://roads.googleapis.com/v1/speedLimits?'+param+'&key='+t;
    http.Response curResponse = await http.get(
      Uri.encodeFull(uri)
    );
    setState(() {
      response=curResponse;
    });
    var jsondecoded=json.decode(response.body);
    if (response.statusCode==200){
      print(jsondecoded['speedLimits']);
      setState(() {
        disp=jsondecoded['speedLimits'][0]['speedLimit'];
      });
      print(jsondecoded['speedLimits'][0]['speedLimit']);
    } else if (response.statusCode==429) {
      print(jsondecoded['error']['message']);
      showDialog(
        context: context,
        builder: (BuildContext context){
          return AlertDialog(
            title: new Text('Daily quota reached'),
            content: new Text("Sorry! But you can use only one request per day if you're using the student plan. "+jsondecoded['error']['message']),
            actions: <Widget>[
              new FlatButton(
                child: new Text('Ok'),
                onPressed: (){
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        }
      );
    }
  }

  void _onMapCreated(GoogleMapController controller){
    setState(() {
      mapController=controller;
    });
  }

  _addMarker(){
    var marker = MarkerOptions(
      position: mapController.cameraPosition.target,
      icon: BitmapDescriptor.defaultMarker,
      infoWindowText: InfoWindowText('Your location', '')
    );
    print(mapController.cameraPosition.target);
    mapController.addMarker(marker);
  }

  _animateToUser() async {
    var pos = await location.getLocation();

    mapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(pos.latitude, pos.longitude),
        zoom: 17.0,
        )
      )
    );
  }

}
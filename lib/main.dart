import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

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
  String disp;
  Firestore firestore =Firestore.instance;
  Geoflutterfire geo =Geoflutterfire();
  BehaviorSubject<double> radius =BehaviorSubject(seedValue: 100.0);
  Stream<dynamic> query;
  StreamSubscription subscription;

  @override
  void initState(){
    super.initState();
    disp='Please click the play button to get the speed';
  }

  build(context) {
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
            onPressed:  _addGeoPoint
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
        left: 10,
        child: Slider(
          min: 100.0,
          max: 500.0,
          divisions: 4,
          value: radius.value,
          label: 'Radius ${radius.value}km',
          activeColor: Colors.green,
          inactiveColor: Colors.green.withOpacity(0.2),
          onChanged: _updateQuery,
        )
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
    String la1=position.latitude.toString();
    String la2=(position.latitude+0.00001).toString();
    String la3=(position.latitude+0.00002).toString();
    String lo1=position.longitude.toString();
    String lo2=(position.longitude+0.00001).toString();
    String lo3=(position.longitude+0.00002).toString();
    String param='path='+la1+','+lo1+'|'+la2+','+lo2+'|'+la3+','+lo3;
    String t='AIzaSyAZHZCliFwEcm6AlLeRuctFCqIY-aBGaGE';
    String t2='AIzaSyCZSwJSBuEa7EfBHqBAaYkEy-tbOKdHOa4';
    String uri = 'https://roads.googleapis.com/v1/speedLimits?'+param+'&key='+t2;
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
            content: new Text("Sorry! But you can use only one request per day if you're using the basic plan. "+jsondecoded['error']['message']),
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

  Future<DocumentReference> _addGeoPoint() {
    var marker = MarkerOptions(
      position: mapController.cameraPosition.target,
      icon: BitmapDescriptor.defaultMarker,
      infoWindowText: InfoWindowText('Your location', '')
    );
    print(mapController.cameraPosition.target);
    mapController.addMarker(marker);
    var pos =mapController.cameraPosition.target;
    GeoFirePoint point = geo.point(latitude: pos.latitude, longitude: pos.longitude);
    return firestore.collection('locations').add({
      'position':point.data,
      'name':'Location query'
    });
  }

  void _updateMarkers(List<DocumentSnapshot> documentList){
    // mapController.clearMarkers();
    documentList.forEach((DocumentSnapshot document){
      GeoPoint pos =document.data['position']['geopoint'];
      double distance =document.data['distance'];
      var marker =MarkerOptions(
        position: mapController.cameraPosition.target,
        icon: BitmapDescriptor.defaultMarker,
        infoWindowText: InfoWindowText('Your location', '$distance km from center point')
      );
      mapController.addMarker(marker);
    });
  }

  _startQuery(){
    var pos =mapController.cameraPosition.target;
    double lat=pos.latitude;
    double lng=pos.longitude;
    var ref =firestore.collection('locations');
    GeoFirePoint center = geo.point(latitude: lat,longitude: lng);

    subscription =radius.switchMap((rad){
      return geo.collection(collectionRef: ref).within(
        center: center,
        radius: rad,
        field: 'position',
        strictMode: true
      );
    }).listen(_updateMarkers);
  }

  _updateQuery(value) {

    final zoomMap = {
      100.0: 12.0,
      200.0: 10.0,
      300.0: 7.0,
      400.0: 6.0,
      500.0: 5.0
    };

    final zoom =zoomMap[value];
    mapController.moveCamera(CameraUpdate.zoomTo(zoom));

    setState(() {
      radius.add(value);
    });
  }

  @override
  dispose() {
    subscription.cancel();
    super.dispose();
  }

}
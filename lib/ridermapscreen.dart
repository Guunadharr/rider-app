import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class RiderMapScreen extends StatefulWidget {
  const RiderMapScreen({Key? key}) : super(key: key);

  @override
  State<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen> {
  Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  var _currentPosition;
  BitmapDescriptor? sourceIcon;
  BitmapDescriptor? driverIcon;
  MqttServerClient? riderClient;

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
    loadSourceIcon();
    loadDriverIcon();
    connectToBroker();
  }

  // rider icon
  void loadSourceIcon() async {
    sourceIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(48, 48)),
      'assets/icons/ic_marker.png',
    );
  }

  // driver icon
  void loadDriverIcon() async {
    driverIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(48, 48)),
      'assets/icons/ic_car.png',
    );
  }

  Future<void> connectToBroker() async {
    riderClient =
        MqttServerClient.withPort("test.mosquitto.org", "RiderClient", 1883);
    riderClient!.onConnected = onUserConnected;
    riderClient!.onDisconnected = onUserDisconnected;
    riderClient!.onSubscribed = onUserSubscribed;

    try {
      await riderClient!.connect();
      riderClient!.subscribe('driver_location', MqttQos.atLeastOnce);
    } catch (e) {
      print('Failed to connect to broker: $e');
    }

    if (riderClient!.connectionStatus!.state == MqttConnectionState.connected) {
      riderClient!.onSubscribed = onUserSubscribed;

      debugPrint('connected');
    } else {
      riderClient!.connect();
    }
  }

  void onUserConnected() {
    print('User client connected');
    // Perform MQTT operations or any other necessary actions
  }

  void onUserDisconnected() {
    print('User client disconnected');
    // Handle disconnection scenarios if needed
  }

  void onUserSubscribed(String topic) {
    print('User client subscribed to topic: $topic');
    // Handle subscription success if needed

    // Subscribe to the topic to receive driver location updates
    riderClient!.updates!
        .listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final message = messages[0].payload as MqttPublishMessage;
      final driverLocation =
          MqttPublishPayload.bytesToStringAsString(message.payload.message);

      // Call updateDriverLocation to update the driver's location on the map
      updateDriverLocation(driverLocation);
    });
  }

  void updateDriverLocation(String driverLocation) {
    // Parse the driver's location string to get latitude and longitude
    final locationParts = driverLocation.split(',');
    final latitude = double.tryParse(locationParts[0]);
    final longitude = double.tryParse(locationParts[1]);

    if (latitude != null && longitude != null) {
      setState(() {
        _markers.removeWhere(
            (marker) => marker.markerId.value == 'Driver location');
        _markers.add(
          Marker(
            markerId: MarkerId('Driver location'),
            position: LatLng(latitude, longitude),
            // Set the driver icon here
            icon: driverIcon!,
            infoWindow: InfoWindow(title: 'Driver Location'),
          ),
        );
      });
    }
  }

  // getting current location
  void getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _markers.add(
          Marker(
            markerId: MarkerId('Your location'),
            position: LatLng(
              _currentPosition.latitude,
              _currentPosition.longitude,
            ),
            icon: sourceIcon!,
            infoWindow: InfoWindow(title: 'Current Location'),
          ),
        );
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rider Map'),
      ),
      body: _currentPosition != null
          ? GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentPosition.latitude,
                  _currentPosition.longitude,
                ),
                zoom: 18.0,
              ),
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            )
          : Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}

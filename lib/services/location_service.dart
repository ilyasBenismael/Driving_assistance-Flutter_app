import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';


class LocationService {
  final BuildContext context;

  LocationService(this.context);


///////////////////////////////////////// CHECK LOCATION PERMISSION //////////////////////////////////////////////

  //for each case show msg, and return 1 only if all is permitted
  Future<int> checkPermissions() async {
    try {
      bool locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationEnabled) {
        _toastMsg('You need to activate the location');
        return -1;
      }

      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _toastMsg('You need to give permission for location access');
        return -2;
      } else {
        return 1;
      }
    } catch (e) {
      _toastMsg('Error while getting location permission');
      return -3;
    }
  }



///////////////////////////////////////////////// SETTING UP SPEED /////////////////////////////////////////////////

  //we return 1 if all good
  Future<int> setUpSpeed(Function(double) onSpeedChanged) async {
    int permissionStatus = await checkPermissions();
    if (permissionStatus != 1) {
      return permissionStatus;
    }

    //if it's not android it won't work, we make a 3sec speed update
    if (defaultTargetPlatform == TargetPlatform.android) {
      Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 2),
        ),
      ).listen((Position position) {
        onSpeedChanged(position.speed * 3.6); // Speed in km/h
      });
      return 1;
    } else {
      _toastMsg('Not an Android platform');
      return -1;
    }
  }

  void _toastMsg(String msg) {
    final snackBar = SnackBar(content: Text(msg));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}


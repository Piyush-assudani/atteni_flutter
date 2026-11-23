import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

// HIDDEN FOR PLAY STORE RELEASE - Geolocator removed.
// Uncomment this whole logic later when discussing.

class LiveTrackingService {
  static final LiveTrackingService _instance = LiveTrackingService._internal();
  factory LiveTrackingService() => _instance;
  LiveTrackingService._internal();

  Future<void> startTracking(String vehicleName) async {
    // Disabled
  }

  Future<void> stopTracking() async {
    // Disabled
  }

  /*
  StreamSubscription<dynamic>? _positionStream;
  String? _currentVehicle;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  
  Map<String, String>? _deviceInfoCache;

  Future<Map<String, String>> _getDeviceInfo() async {
    // ...
    return {};
  }
  */
}

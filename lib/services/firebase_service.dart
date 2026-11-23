import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseDatabase db = FirebaseDatabase.instance;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint('Firebase Initialized Successfully');
      
      // Start tracking Server Time Offset to match JS
      FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.listen((event) {
        final val = event.snapshot.value;
        if (val is int) {
          _serverTimeOffset = val;
        } else if (val is double) {
          _serverTimeOffset = val.toInt();
        }
      });
    } catch (e) {
      debugPrint('Firebase Init Error: $e');
    }
  }

  static int _serverTimeOffset = 0;

  // Synced server date matching JS `window.getServerDate()`
  static DateTime getServerDate() {
    return DateTime.now().add(Duration(milliseconds: _serverTimeOffset));
  }

  // Common references based on app state logic
  DatabaseReference getBaseRef(String school) {
    if (school == 'DPS') {
      return db.ref('artifacts/student-system-v2/public/data');
    }
    return db.ref('artifacts/student-system-v2/public/data/$school');
  }

  // Auth Methods (OTP)
  Future<ConfirmationResult> signInWithPhone(String phone) async {
    String formattedPhone = phone;
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+91$phone';
    }
    // signInWithPhoneNumber automatically handles reCAPTCHA on web
    return await auth.signInWithPhoneNumber(formattedPhone);
  }

  Future<UserCredential> verifyWebOTP(ConfirmationResult confirmationResult, String smsCode) async {
    return await confirmationResult.confirm(smsCode);
  }
}

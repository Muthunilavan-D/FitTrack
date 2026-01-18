import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class WaterIntakeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _currentIntake = 0;
  int _dailyGoal = 2000; // 2L in ml
  StreamSubscription<DocumentSnapshot>? _waterIntakeSubscription;

  WaterIntakeProvider() {
    _initializeListener();
  }

  int get currentIntake => _currentIntake;
  int get dailyGoal => _dailyGoal;
  double get progressPercentage => _currentIntake / _dailyGoal;
  bool get isGoalAchieved => _currentIntake >= _dailyGoal;
  double get remainingWater =>
      (_dailyGoal - _currentIntake) / 1000; // Convert to L

  void _initializeListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Cancel existing subscription if any
    _waterIntakeSubscription?.cancel();

    // Listen to water intake changes
    _waterIntakeSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('water_intake')
        .doc(today)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _currentIntake = snapshot.data()?['amount'] ?? 0;
        notifyListeners();
      }
    });
  }

  Future<void> loadTodayIntake() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('water_intake')
        .doc(today)
        .get();

    if (doc.exists) {
      _currentIntake = doc.data()?['amount'] ?? 0;
      notifyListeners();
    }
  }

  Future<void> addWater(double amount) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final amountInMl = (amount * 1000).toInt(); // Convert L to ml
    _currentIntake += amountInMl;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('water_intake')
        .doc(today)
        .set({
      'amount': _currentIntake,
      'lastUpdated': FieldValue.serverTimestamp(),
      'goal': _dailyGoal,
    }, SetOptions(merge: true));

    notifyListeners();
  }

  Future<void> setDailyGoal(int goalInMl) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _dailyGoal = goalInMl;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('water_intake')
        .doc(today)
        .set({
      'goal': _dailyGoal,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    notifyListeners();
  }

  Future<void> resetIntake() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _currentIntake = 0;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('water_intake')
        .doc(today)
        .set({
      'amount': 0,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    notifyListeners();
  }

  @override
  void dispose() {
    _waterIntakeSubscription?.cancel();
    super.dispose();
  }
}

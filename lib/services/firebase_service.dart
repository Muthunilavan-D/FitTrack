import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;
  
  // Water Intake Methods
  Future<void> updateWaterIntake(double amount) async {
    if (currentUserId == null) return;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('waterIntake')
        .doc(today)
        .set({
          'amount': amount,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<double> getWaterIntake() async {
    if (currentUserId == null) return 0.0;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('waterIntake')
        .doc(today)
        .get();

    return doc.exists ? (doc.data()?['amount'] ?? 0.0) : 0.0;
  }

  // Workout Progress Methods
  Future<void> updateWorkoutProgress(int completedExercises, int totalExercises) async {
    if (currentUserId == null) return;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('workoutProgress')
        .doc(today)
        .set({
          'completedExercises': completedExercises,
          'totalExercises': totalExercises,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getWorkoutProgress() async {
    if (currentUserId == null) {
      return {
        'completedExercises': 0,
        'totalExercises': 10,
      };
    }
    
    final today = DateTime.now().toIso8601String().split('T')[0];
    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('workoutProgress')
        .doc(today)
        .get();

    if (!doc.exists) {
      return {
        'completedExercises': 0,
        'totalExercises': 10,
      };
    }

    return {
      'completedExercises': doc.data()?['completedExercises'] ?? 0,
      'totalExercises': doc.data()?['totalExercises'] ?? 10,
    };
  }

  // Steps Counter Methods
  Future<void> updateStepsCount(int steps) async {
    if (currentUserId == null) return;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('steps')
        .doc(today)
        .set({
          'count': steps,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<int> getStepsCount() async {
    if (currentUserId == null) return 0;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('steps')
        .doc(today)
        .get();

    return doc.exists ? (doc.data()?['count'] ?? 0) : 0;
  }
} 
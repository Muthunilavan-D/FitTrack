import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/program_data.dart';
import '../services/firebase_service.dart';

class WorkoutProgressProvider extends ChangeNotifier {
  Set<String> _completedExercises = {};
  String _selectedProgram = 'Jog'; // Default program
  DateTime _lastUpdate = DateTime.now();
  final FirebaseService _firebaseService = FirebaseService();

  // Calculate total exercises from all programs
  final int _totalExercises = ProgramData.exercises.values
      .fold(0, (sum, exercises) => sum + exercises.length);

  WorkoutProgressProvider() {
    _loadData();
  }

  // Getters
  Set<String> get completedExercises => _completedExercises;
  String get selectedProgram => _selectedProgram;
  int get completedExercisesCount => _completedExercises.length;
  int get remainingExercises => _totalExercises - completedExercisesCount;
  double get progressPercentage =>
      (completedExercisesCount / _totalExercises).clamp(0.0, 1.0);
  DateTime get lastUpdate => _lastUpdate;

  bool isExerciseCompleted(String programName, String exerciseName) {
    return _completedExercises.contains('${programName}_$exerciseName');
  }

  Future<void> _loadData() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_firebaseService.currentUserId)
        .collection('workoutProgress')
        .doc(today)
        .get();

    if (doc.exists) {
      final data = doc.data();
      _completedExercises = (data?['completedExercises'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          {};
      _selectedProgram = data?['selectedProgram'] ?? 'Jog';
    } else {
      _completedExercises = {};
      _selectedProgram = 'Jog';
    }

    _lastUpdate = DateTime.now();
    notifyListeners();
  }

  Future<void> _saveData() async {
    if (_firebaseService.currentUserId == null) return;
    final today = DateTime.now().toIso8601String().split('T')[0];
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_firebaseService.currentUserId)
        .collection('workoutProgress')
        .doc(today)
        .set({
      'completedExercises': _completedExercises.toList(),
      'selectedProgram': _selectedProgram,
      'totalExercises': _totalExercises,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> completeExercise(String programName, String exerciseName) async {
    if (_firebaseService.currentUserId == null) return;
    if (!_isSameDay(_lastUpdate, DateTime.now())) {
      _completedExercises = {};
      _lastUpdate = DateTime.now();
    }
    final exerciseId = '${programName}_$exerciseName';
    if (!_completedExercises.contains(exerciseId)) {
      _completedExercises.add(exerciseId);
      await _saveData();
      notifyListeners();
    }
  }

  Future<void> setSelectedProgram(String programName) async {
    if (_firebaseService.currentUserId == null) return;
    _selectedProgram = programName;
    await _saveData();
    notifyListeners();
  }

  Future<void> resetProgress() async {
    if (_firebaseService.currentUserId == null) return;
    _completedExercises = {};
    _lastUpdate = DateTime.now();
    await _saveData();
    notifyListeners();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/food_entry.dart';
import '../services/food_service.dart';

class FoodProvider extends ChangeNotifier {
  final FoodService _foodService = FoodService();
  
  File? _currentImage;
  bool _isProcessing = false;
  String _errorMessage = '';
  List<FoodEntry> _todayEntries = [];
  Map<String, num> _dailyTotals = {'calories': 0, 'protein': 0};

  // Getters
  File? get currentImage => _currentImage;
  bool get isProcessing => _isProcessing;
  String get errorMessage => _errorMessage;
  List<FoodEntry> get todayEntries => _todayEntries;
  Map<String, num> get dailyTotals => _dailyTotals;

  FoodProvider() {
    // Initialize streams
    _foodService.getTodaysFoodEntries().listen((entries) {
      _todayEntries = entries;
      notifyListeners();
    });

    _foodService.getDailyTotals().listen((totals) {
      _dailyTotals = totals;
      notifyListeners();
    });
  }

  // Set current image
  void setCurrentImage(File? image) {
    _currentImage = image;
    _errorMessage = '';
    notifyListeners();
  }

  // Process image and add food entry
  Future<void> processImage() async {
    if (_currentImage == null) {
      _errorMessage = 'No image selected';
      notifyListeners();
      return;
    }

    try {
      _isProcessing = true;
      _errorMessage = '';
      notifyListeners();

      final result = await _foodService.analyzeImage(_currentImage!);
      
      if (result != null) {
        await _foodService.addFoodEntry(
          name: result['name'] ?? 'Unknown food',
          calories: result['calories']?.toInt() ?? 0,
          protein: (result['protein_g'] ?? 0).toDouble(),
          image: _currentImage,
        );

        // Clear current image after successful processing
        _currentImage = null;
      } else {
        _errorMessage = 'Could not analyze the image';
      }
    } catch (e) {
      _errorMessage = 'Error processing image: $e';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  // Delete food entry
  Future<void> deleteFoodEntry(String entryId) async {
    try {
      await _foodService.deleteFoodEntry(entryId);
    } catch (e) {
      _errorMessage = 'Error deleting entry: $e';
      notifyListeners();
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
} 
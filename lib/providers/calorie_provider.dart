import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class CalorieProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  File? currentImage;
  String detectedFood = "";
  int calories = 0;
  int protein = 0;
  int totalCalories = 0;
  int totalProtein = 0;
  bool isLoading = false;

  String? get userId => _auth.currentUser?.uid;

  final String apiKey = "AIzaSyAF3K5Jnzqyn-ThTUe01mi3im5oitHIU6I";

  // Load stored data from Firebase
  Future<void> loadStoredData() async {
    if (userId == null) return;

    try {
      DocumentSnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('nutrition')
          .doc(DateFormat('dd-MM-yyyy').format(DateTime.now()))
          .get();

      if (snapshot.exists) {
        totalCalories = snapshot.get('totalCalories') ?? 0;
        totalProtein = snapshot.get('totalProtein') ?? 0;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading stored data: $e');
    }
  }

  // Update Firebase with new calorie and protein totals
  Future<void> updateStoredData() async {
    if (userId == null) return;

    final String today = DateFormat('dd-MM-yyyy').format(DateTime.now());
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('nutrition')
          .doc(today)
          .set({
        'totalCalories': totalCalories,
        'totalProtein': totalProtein,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating stored data: $e');
    }
  }

  // Analyze image using Gemini API
  Future<void> analyzeImage(File imageFile) async {
    try {
      setLoading(true);
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey",
      );

      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    "Identify the food item in the image and estimate its calories and protein content.(just give name of the dish that show in image and then give exact calories and protein content in the format: Calories: X kcal, Protein: Y g.)",
              },
              {
                "inlineData": {"mimeType": "image/jpeg", "data": base64Image},
              },
            ],
          },
        ],
      };

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse.containsKey("candidates") &&
            jsonResponse["candidates"].isNotEmpty) {
          detectedFood = jsonResponse["candidates"][0]["content"]["parts"][0]
                  ["text"] ??
              "Could not identify food.";
          notifyListeners();

          await fetchNutritionalInfo(detectedFood);
        } else {
          detectedFood = "No food detected. Try another image.";
          notifyListeners();
        }
      } else {
        detectedFood = "Error: ${response.statusCode}";
        notifyListeners();
      }
    } catch (e) {
      detectedFood = "Error detecting food. Please try again.";
      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  // Fetch Calories and Protein for Detected Food
  Future<void> fetchNutritionalInfo(String foodName) async {
    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey",
      );

      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text":
                      "Provide the exact calorie and protein content for $foodName. Reply strictly in the format: Calories: X kcal, Protein: Y g.",
                }
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        String textResponse = jsonResponse['candidates']?[0]['content']
                ?['parts']?[0]['text'] ??
            "Calories: 0 kcal, Protein: 0 g";

        RegExp calExp =
            RegExp(r'Calories:\s*(\d+)\s*kcal', caseSensitive: false);
        RegExp proExp = RegExp(r'Protein:\s*(\d+)\s*g', caseSensitive: false);

        calories =
            int.tryParse(calExp.firstMatch(textResponse)?.group(1) ?? "0") ?? 0;
        protein =
            int.tryParse(proExp.firstMatch(textResponse)?.group(1) ?? "0") ?? 0;

        totalCalories += calories;
        totalProtein += protein;

        await updateStoredData();
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching nutritional info: $e');
    }
  }

  // Save daily totals and reset
  Future<void> finishAndSaveData() async {
    if (userId == null) return;

    try {
      String date = DateFormat('dd-MM-yyyy').format(DateTime.now());

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('nutrition_history')
          .doc(date)
          .set({
        'totalCalories': totalCalories,
        'totalProtein': totalProtein,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Reset the daily totals
      totalCalories = 0;
      totalProtein = 0;
      calories = 0;
      protein = 0;
      detectedFood = "";
      currentImage = null;

      notifyListeners();
    } catch (e) {
      print('Error saving daily totals: $e');
    }
  }

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void setCurrentImage(File? image) {
    currentImage = image;
    detectedFood = "";
    calories = 0;
    protein = 0;
    notifyListeners();
  }

  void updateNutritionData(Map<String, dynamic> data) {
    if (data.isNotEmpty) {
      detectedFood = data['name'] ?? 'Unknown food';
      calories = data['calories']?.toInt() ?? 0;
      protein = data['protein_g']?.toDouble() ?? 0.0;
      totalCalories += calories;
      totalProtein += protein;
      notifyListeners();
    }
  }
}

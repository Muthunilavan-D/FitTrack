import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/food_entry.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // TODO: Replace with your Gemini API key from https://makersuite.google.com/app/apikey
  final String _apiKey = "REPLACE_WITH_YOUR_GEMINI_API_KEY";
  
  // TODO: Replace with your Cloudinary configuration from your Cloudinary dashboard
  // 1. Get cloud name from your dashboard
  // 2. Create an upload preset in Settings > Upload > Upload presets
  final String cloudName = "REPLACE_WITH_YOUR_CLOUD_NAME";
  final String uploadPreset = "REPLACE_WITH_YOUR_UPLOAD_PRESET";
  final String cloudinaryUrl = "https://api.cloudinary.com/v1_1/REPLACE_WITH_YOUR_CLOUD_NAME/image/upload";

  String? get userId => _auth.currentUser?.uid;

  // Upload image to Cloudinary
  Future<String?> _uploadImage(File imageFile) async {
    if (userId == null) return null;

    try {
      final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;
      
      final stream = http.ByteStream(imageFile.openRead());
      final length = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'file',
        stream,
        length,
        filename: '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      
      request.files.add(multipartFile);
      final response = await request.send();
      
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final parsedResponse = json.decode(responseData);
        return parsedResponse['secure_url'];
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Analyze image using Gemini API
  Future<Map<String, dynamic>?> analyzeImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey",
      );

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text": "Identify the food item in this image and provide its nutritional information. Reply in JSON format with these fields: name (string), calories (number), protein_g (number)",
                },
                {
                  "inlineData": {
                    "mimeType": "image/jpeg",
                    "data": base64Image
                  }
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['candidates'] != null && 
            jsonResponse['candidates'].isNotEmpty) {
          final text = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
          // Extract JSON from the response text
          final jsonMatch = RegExp(r'{.*}').firstMatch(text);
          if (jsonMatch != null) {
            return jsonDecode(jsonMatch.group(0)!);
          }
        }
      }
      return null;
    } catch (e) {
      print('Error analyzing image: $e');
      return null;
    }
  }

  // Add food entry to Firestore
  Future<FoodEntry?> addFoodEntry({
    required String name,
    required int calories,
    required double protein,
    File? image,
  }) async {
    if (userId == null) return null;

    try {
      final String id = const Uuid().v4();
      final DateTime timestamp = DateTime.now();
      
      String? imageUrl;
      if (image != null) {
        imageUrl = await _uploadImage(image);
      }

      final FoodEntry entry = FoodEntry(
        id: id,
        name: name,
        calories: calories,
        protein: protein,
        timestamp: timestamp,
        imageUrl: imageUrl,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('food_entries')
          .doc(id)
          .set(entry.toMap());

      return entry;
    } catch (e) {
      print('Error adding food entry: $e');
      return null;
    }
  }

  // Get today's food entries
  Stream<List<FoodEntry>> getTodaysFoodEntries() {
    if (userId == null) {
      return Stream.value([]);
    }

    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('food_entries')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThan: endOfDay)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FoodEntry.fromFirestore(doc))
              .toList();
        });
  }

  // Get daily totals
  Stream<Map<String, num>> getDailyTotals() {
    return getTodaysFoodEntries().map((entries) {
      int totalCalories = 0;
      double totalProtein = 0;

      for (var entry in entries) {
        totalCalories += entry.calories;
        totalProtein += entry.protein;
      }

      return {
        'calories': totalCalories,
        'protein': totalProtein,
      };
    });
  }

  // Delete food entry
  Future<void> deleteFoodEntry(String entryId) async {
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('food_entries')
          .doc(entryId)
          .delete();
    } catch (e) {
      print('Error deleting food entry: $e');
    }
  }
} 
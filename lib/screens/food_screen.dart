import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _detectedFood = "";
  int _calories = 0;
  int _protein = 0;
  int _totalCalories = 0;
  int _totalProtein = 0;
  bool _isAnalyzing = false;
  
  // Gemini API Key - Make sure this key has proper permissions in Google Cloud Console
  // The key needs access to Gemini API and should not have IP restrictions
  final String _geminiApiKey = "YOUR_API_KEY";

  @override
  void initState() {
    super.initState();
    _loadTodaysTotals();
  }

  Future<void> _loadTodaysTotals() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Listen to nutrition history changes
    _firestore
        .collection('users')
        .doc(user.uid)
        .collection('nutrition_history')
        .doc(today)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _totalCalories = snapshot.data()?['totalCalories'] ?? 0;
          _totalProtein = snapshot.data()?['totalProtein'] ?? 0;
        });
      }
    });
  }

  Future<void> _pickAndAnalyzeImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      // Validate that it's actually an image file, not a video
      final filePath = pickedFile.path.toLowerCase();
      final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv', '.3gp'];
      final isVideo = videoExtensions.any((ext) => filePath.endsWith(ext));
      
      if (isVideo) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Videos are not supported. Please select an image file (JPG, PNG, etc.)',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      setState(() {
        _image = File(pickedFile.path);
        _detectedFood = "Analyzing...";
        _calories = 0;
        _protein = 0;
        _isAnalyzing = true;
      });

      await _analyzeImage();
    } catch (e) {
      setState(() {
        _detectedFood = "Error picking image";
        _isAnalyzing = false;
      });

      if (!mounted) return;
      
      String errorMsg = 'Error picking image';
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('video')) {
        errorMsg = 'Videos are not supported. Please select an image file (JPG, PNG, etc.)';
      } else if (errorString.contains('permission')) {
        errorMsg = 'Permission denied. Please allow access to photos.';
      } else {
        errorMsg = 'Error: ${e.toString()}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    try {
      // Validate API key
      if (_geminiApiKey.isEmpty || _geminiApiKey == "YOUR_API_KEY_HERE") {
        throw Exception("Gemini API key is not configured. Please add a valid API key.");
      }

      // Double-check file is an image, not a video
      final filePath = _image!.path.toLowerCase();
      final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv', '.3gp', '.m4v'];
      if (videoExtensions.any((ext) => filePath.endsWith(ext))) {
        throw Exception("Videos are not supported. Please select an image file (JPG, PNG, etc.)");
      }

      // Read image and convert to base64
      final bytes = await _image!.readAsBytes();
      
      // Check image size (Gemini has limits - 20MB for base64)
      if (bytes.length > 15 * 1024 * 1024) { // 15MB limit to account for base64 encoding overhead
        throw Exception("Image is too large. Please use an image smaller than 15MB.");
      }
      
      final base64Image = base64Encode(bytes);
      
      // Detect MIME type from file extension
      String mimeType = "image/jpeg";
      final imagePath = _image!.path.toLowerCase();
      if (imagePath.endsWith('.png')) {
        mimeType = "image/png";
      } else if (imagePath.endsWith('.webp')) {
        mimeType = "image/webp";
      } else if (imagePath.endsWith('.gif')) {
        mimeType = "image/gif";
      }

      // List of models to try in order (verified working models)
      final List<String> modelsToTry = [
        'gemini-1.5-flash',         // Most commonly available - supports images
        'gemini-1.5-pro',           // Pro version - supports images
        'gemini-pro',                // Legacy pro - supports images
      ];

      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    "You are a nutrition expert. Analyze this food image carefully and provide ONLY the following information in this EXACT format (no additional text, no explanations):\n\nFood Name: [specific name of the dish/food item]\nCalories: [number] kcal\nProtein: [number] g\n\nIMPORTANT RULES:\n1. Food Name: Be very specific (e.g., 'Grilled Chicken Breast' not just 'Chicken', 'Apple' not just 'Fruit')\n2. Calories: Provide accurate calories for the visible serving size in the image (must be a whole number)\n3. Protein: Provide protein in grams for the visible serving (can be decimal, will be rounded)\n4. If you cannot identify the food clearly, use 'Unknown Food' as the name\n5. If you cannot estimate nutrition, use 0 for calories and protein\n6. Do NOT include any other text, explanations, or formatting beyond the 3 lines above",
              },
              {
                "inlineData": {"mimeType": mimeType, "data": base64Image},
              },
            ],
          },
        ],
      };

      http.Response? response;
      String? lastError;
      bool success = false;

      // Try each model until one works
      for (String model in modelsToTry) {
        try {
          // Use correct API endpoint format
          final uri = Uri.parse(
            "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiApiKey",
          );

          // Make the request with proper error handling
          response = await http.post(
            uri,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode(requestBody),
          ).timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              throw Exception("Request timeout for model $model");
            },
          );

          // If we get a 200, break and use this response
          if (response.statusCode == 200) {
            success = true;
            break;
          }
          
          // If it's a 404 (model not found), try next model
          if (response.statusCode == 404) {
            final errorBody = jsonDecode(response.body);
            lastError = errorBody['error']?['message'] ?? 'Model $model not found';
            continue; // Try next model
          }
          
          // For other errors, break and handle them
          if (response.statusCode != 200) {
            break;
          }
        } catch (e) {
          // If timeout or network error, try next model
          String errorMsg = e.toString();
          
          // Check for specific network errors
          if (errorMsg.contains('SocketException') || 
              errorMsg.contains('Failed host lookup') ||
              errorMsg.contains('Network is unreachable') ||
              errorMsg.contains('No Internet')) {
            lastError = 'Network error: Unable to connect. Please check your internet connection.';
            // Don't continue to next model if it's a network issue - it will fail for all
            if (model == modelsToTry.first) {
              // Only break on first model if it's clearly a network issue
              break;
            }
            continue;
          }
          
          lastError = errorMsg;
          continue;
        }
      }

      // If no model worked, throw error with detailed information
      if (!success || response == null) {
        String errorDetails = lastError ?? 'Unknown error';
        
        // Provide specific guidance based on error type
        if (errorDetails.contains('Network error') || 
            errorDetails.contains('Unable to connect') ||
            errorDetails.contains('SocketException') ||
            errorDetails.contains('Failed host lookup')) {
          throw Exception(
            "Network connection failed. Please check:\n"
            "1. Your internet connection is active\n"
            "2. No firewall is blocking the connection\n"
            "3. Try again in a moment\n"
            "Error: $errorDetails"
          );
        } else if (errorDetails.contains('403') || errorDetails.contains('Access Denied')) {
          throw Exception(
            "API Access Denied. Please check:\n"
            "1. Your Gemini API key is valid\n"
            "2. API key has proper permissions\n"
            "3. API key is not blocked or revoked\n"
            "Error: $errorDetails"
          );
        } else if (errorDetails.contains('404') || errorDetails.contains('not found')) {
          throw Exception(
            "Gemini API models not available. Please check:\n"
            "1. Your API key has access to Gemini models\n"
            "2. Try updating your API key\n"
            "Error: $errorDetails"
          );
        } else {
          throw Exception(
            "Failed to connect to Gemini API.\n"
            "Error: $errorDetails\n"
            "Please check your internet connection and API key."
          );
        }
      }

      // Process successful response (we know statusCode is 200 here)
      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse.containsKey("candidates") &&
          jsonResponse["candidates"].isNotEmpty) {
        final textResponse = jsonResponse["candidates"][0]["content"]["parts"][0]
                ["text"] ??
            "";

        // Parse the response
        String name = "Unknown food";
        int calories = 0;
        int protein = 0;

          // Extract food name - improved parsing
          String cleanedResponse = textResponse.trim();
          
          // Try multiple patterns for food name
          List<RegExp> namePatterns = [
            RegExp(r'Food Name:\s*(.+?)(?:\n|Calories:|$)', caseSensitive: false),
            RegExp(r'^Food Name:\s*(.+?)$', caseSensitive: false, multiLine: true),
            RegExp(r'Food Name:\s*([^\n]+)', caseSensitive: false),
          ];
          
          RegExp? matchedPattern;
          for (var pattern in namePatterns) {
            if (pattern.hasMatch(cleanedResponse)) {
              matchedPattern = pattern;
              break;
            }
          }
          matchedPattern ??= RegExp(r'Food Name:\s*(.+?)(?:\n|Calories:)', caseSensitive: false);
          
          final nameMatch = matchedPattern.firstMatch(cleanedResponse);
          if (nameMatch != null) {
            name = nameMatch.group(1)?.trim() ?? "Unknown Food";
            // Clean up common artifacts
            name = name.replaceAll(RegExp(r'^\*\s*|\s*\*$|^-\s*|\s*-$'), '').trim();
            if (name.isEmpty || name.toLowerCase() == 'unknown' || name.toLowerCase() == 'n/a') {
              name = "Unknown Food";
            }
          } else {
            // Fallback: try to find food name at the start
            final lines = cleanedResponse.split('\n');
            for (var line in lines) {
              final trimmedLine = line.trim();
              if (trimmedLine.toLowerCase().startsWith('food name:')) {
                name = trimmedLine.replaceFirst(RegExp(r'^Food Name:\s*', caseSensitive: false), '').trim();
                if (name.isNotEmpty && name.toLowerCase() != 'unknown' && name.toLowerCase() != 'n/a') {
                  break;
                }
              } else if (!trimmedLine.toLowerCase().contains('calories') && 
                         !trimmedLine.toLowerCase().contains('protein') &&
                         !trimmedLine.toLowerCase().contains('kcal') &&
                         trimmedLine.isNotEmpty &&
                         !RegExp(r'^\d+').hasMatch(trimmedLine)) {
                name = trimmedLine;
                break;
              }
            }
            if (name.isEmpty || name.toLowerCase() == 'unknown' || name.toLowerCase() == 'n/a') {
              name = "Unknown Food";
            }
          }

          // Extract calories - improved parsing with multiple patterns
          List<RegExp> calPatterns = [
            RegExp(r'Calories:\s*(\d+)\s*kcal', caseSensitive: false),
            RegExp(r'Calories:\s*(\d+)', caseSensitive: false),
            RegExp(r'(\d+)\s*kcal', caseSensitive: false),
            RegExp(r'(\d+)\s*cal', caseSensitive: false),
          ];
          
          for (var pattern in calPatterns) {
            final calMatch = pattern.firstMatch(cleanedResponse);
            if (calMatch != null) {
              final calValue = int.tryParse(calMatch.group(1) ?? "0");
              if (calValue != null && calValue > 0) {
                calories = calValue;
                break;
              }
            }
          }

          // Extract protein - improved parsing with multiple patterns
          List<RegExp> proPatterns = [
            RegExp(r'Protein:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false),
            RegExp(r'Protein:\s*(\d+(?:\.\d+)?)', caseSensitive: false),
            RegExp(r'(\d+(?:\.\d+)?)\s*g(?!\w)', caseSensitive: false),
            RegExp(r'(\d+(?:\.\d+)?)\s*grams?', caseSensitive: false),
          ];
          
          for (var pattern in proPatterns) {
            final proMatch = pattern.firstMatch(cleanedResponse);
            if (proMatch != null) {
              final proValue = double.tryParse(proMatch.group(1) ?? "0");
              if (proValue != null && proValue >= 0) {
                protein = proValue.round();
                break;
              }
            }
          }
          
          // Validate extracted values
          if (calories < 0) calories = 0;
          if (protein < 0) protein = 0;
          if (calories > 10000) calories = 0; // Sanity check
          if (protein > 500) protein = 0; // Sanity check

          setState(() {
            _detectedFood = name;
            _calories = calories;
            _protein = protein;
            _isAnalyzing = false;
          });

          // Save to Firestore with user-specific data
          final user = _auth.currentUser;
          if (user != null) {
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            final userRef = _firestore.collection('users').doc(user.uid);
            final nutritionRef =
                userRef.collection('nutrition_history').doc(today);

            // Get current totals from nutrition history
            final nutritionDoc = await nutritionRef.get();
            final currentData = nutritionDoc.data() ?? {};
            final currentCalories = currentData['totalCalories'] ?? 0;
            final currentProtein = currentData['totalProtein'] ?? 0;

            // Create new food entry
            Map<String, dynamic> newFood = {
              'name': _detectedFood,
              'calories': _calories,
              'protein': _protein,
              'addedAt': DateTime.now().millisecondsSinceEpoch,
            };

            // Update nutrition history
            await nutritionRef.set({
              'totalCalories': currentCalories + _calories,
              'totalProtein': currentProtein + _protein,
              'lastUpdated': DateTime.now().millisecondsSinceEpoch,
              'foods': FieldValue.arrayUnion([newFood]),
            }, SetOptions(merge: true));

            // Update daily stats
            await userRef.collection('daily_stats').doc(today).set({
              'totalCalories': currentCalories + _calories,
              'totalProtein': currentProtein + _protein,
              'lastUpdated': DateTime.now().millisecondsSinceEpoch,
            }, SetOptions(merge: true));

            // Show success message
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Food added successfully'),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
      } else {
        throw Exception("No response from Gemini API - empty candidates array");
      }
    } catch (e) {
      setState(() {
        _detectedFood = "Could not analyze food";
        _calories = 0;
        _protein = 0;
        _isAnalyzing = false;
      });

      if (!mounted) return;
      
      // Provide helpful error messages
      String errorMessage = 'Error analyzing food image';
      final errorString = e.toString();
      
      if (errorString.contains('Network connection failed') || 
          errorString.contains('Unable to connect') ||
          errorString.contains('SocketException') ||
          errorString.contains('Failed host lookup') ||
          errorString.contains('No Internet')) {
        errorMessage = 'No internet connection. Please check:\n• Your Wi-Fi or mobile data is on\n• You have internet access\n• Try again in a moment';
      } else if (errorString.contains('All Gemini models failed')) {
        errorMessage = 'Unable to connect to Gemini API.\nPlease check your internet connection and API key.';
      } else if (errorString.contains('timeout') || errorString.contains('Timeout')) {
        errorMessage = 'Request timed out. Please try again with a smaller image.';
      } else if (errorString.contains('403') || errorString.contains('Access Denied')) {
        errorMessage = 'API access denied.\nPlease check your Gemini API key permissions.';
      } else if (errorString.contains('429') || errorString.contains('Rate limit')) {
        errorMessage = 'Rate limit exceeded.\nPlease wait a moment and try again.';
      } else if (errorString.contains('too large') || errorString.contains('15MB')) {
        errorMessage = 'Image is too large.\nPlease use an image smaller than 15MB.';
      } else if (errorString.contains('404') || errorString.contains('not found')) {
        errorMessage = 'Gemini API models not available.\nPlease check:\n• Your API key is valid\n• API key has Gemini access enabled\n• Try again in a moment';
      } else {
        errorMessage = errorString.replaceAll('Exception: ', '');
        // Clean up error message
        if (errorMessage.contains('\n')) {
          // Keep multi-line errors as is
        } else if (errorMessage.length > 80) {
          errorMessage = 'Failed to analyze food image.\nPlease check your connection and try again.';
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMessage,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[900]!,
              Colors.grey[850]!,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.blue[600]!],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Food Tracker',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Analyze your meals',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Modern Image Preview Card
                Container(
                  height: 240,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _image != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(_image!, fit: BoxFit.cover),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.3),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.grey[800]!,
                                  Colors.grey[900]!,
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 56,
                                      color: Colors.blue[300],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Select a food image',
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap the button below',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Modern Action Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: _isAnalyzing
                          ? [Colors.grey[700]!, Colors.grey[800]!]
                          : [Colors.blue[400]!, Colors.blue[600]!],
                    ),
                    boxShadow: _isAnalyzing
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isAnalyzing ? null : _pickAndAnalyzeImage,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isAnalyzing)
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            else
                              const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            const SizedBox(width: 12),
                            Text(
                              _isAnalyzing ? 'Analyzing...' : 'Analyze Food',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 28),
            
            // Analysis Result - Modern Card
            if (_detectedFood.isNotEmpty && _detectedFood != "Analyzing...")
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey[800]!,
                      Colors.grey[900]!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[400]!, Colors.blue[600]!],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.analytics_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Analysis Result',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Food Name Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.restaurant_menu,
                                color: Colors.blue,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Food Item',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _detectedFood,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Calories and Protein Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernStatCard(
                              'Calories',
                              '$_calories',
                              'kcal',
                              Icons.local_fire_department,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModernStatCard(
                              'Protein',
                              '$_protein',
                              'g',
                              Icons.fitness_center,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            // Today's Totals - Modern Card
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey[800]!,
                    Colors.grey[900]!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purple[400]!, Colors.purple[600]!],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.today_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Today\'s Totals',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernStatCard(
                            'Total Calories',
                            '$_totalCalories',
                            'kcal',
                            Icons.local_fire_department,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernStatCard(
                            'Total Protein',
                            '$_totalProtein',
                            'g',
                            Icons.fitness_center,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatCard(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


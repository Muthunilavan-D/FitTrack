import 'package:cloud_firestore/cloud_firestore.dart';

class FoodEntry {
  final String id;
  final String name;
  final int calories;
  final double protein;
  final DateTime timestamp;
  final String? imageUrl;

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.timestamp,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'timestamp': timestamp,
      'imageUrl': imageUrl,
    };
  }

  factory FoodEntry.fromMap(Map<String, dynamic> map) {
    return FoodEntry(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      calories: map['calories']?.toInt() ?? 0,
      protein: (map['protein'] ?? 0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      imageUrl: map['imageUrl'],
    );
  }

  factory FoodEntry.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FoodEntry(
      id: doc.id,
      name: data['name'] ?? '',
      calories: data['calories']?.toInt() ?? 0,
      protein: (data['protein'] ?? 0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'],
    );
  }
} 
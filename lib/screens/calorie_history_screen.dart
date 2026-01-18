import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CalorieHistoryScreen extends StatelessWidget {
  const CalorieHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calorie History'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('nutrition_history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final history = snapshot.data!.docs;

          if (history.isEmpty) {
            return const Center(
              child: Text('No calorie history available'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final data = history[index].data() as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp).toDate();
              final date = DateFormat('MMM dd, yyyy').format(timestamp);

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            '${data['totalCalories'] ?? 0} kcal',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Protein: ${data['totalProtein'] ?? 0} g'),
                      if (data['foods'] != null) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Foods:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...(data['foods'] as List).map((food) => Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: Text('• $food'),
                            )),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

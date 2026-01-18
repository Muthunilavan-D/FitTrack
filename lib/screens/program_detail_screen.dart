import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_progress_provider.dart';

class ProgramDetailScreen extends StatelessWidget {
  final String programName;
  final IconData icon;
  final List<Map<String, dynamic>> exercises;

  const ProgramDetailScreen({
    super.key,
    required this.programName,
    required this.icon,
    required this.exercises,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(programName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Program Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      programName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${exercises.length} exercises',
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Exercise List
          Expanded(
            child: Consumer<WorkoutProgressProvider>(
              builder: (context, workoutProvider, child) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    final isCompleted = workoutProvider.isExerciseCompleted(
                      programName,
                      exercise['name'],
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: isCompleted
                            ? Border.all(color: Colors.green, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise['name'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted ? Colors.green : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  exercise['description'],
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${exercise['duration']} | ${exercise['sets']} sets',
                                  style: const TextStyle(
                                    color: Color(0xFF2196F3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                            ),
                            color: isCompleted ? Colors.green : Colors.blue,
                            onPressed: isCompleted
                                ? null
                                : () {
                                    workoutProvider.completeExercise(
                                      programName,
                                      exercise['name'],
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${exercise['name']} completed!'),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 
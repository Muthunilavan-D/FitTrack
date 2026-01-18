import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/program_detail_screen.dart';
import '../data/program_data.dart';
import '../providers/workout_progress_provider.dart';

class ProgramCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const ProgramCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProgressProvider>(
      builder: (context, workoutProvider, child) {
        return GestureDetector(
          onTap: () {
            workoutProvider.setSelectedProgram(label);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProgramDetailScreen(
                  programName: label,
                  icon: icon,
                  exercises: ProgramData.exercises[label] ?? [],
                ),
              ),
            );
          },
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 
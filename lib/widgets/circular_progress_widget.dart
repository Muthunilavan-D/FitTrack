import 'package:flutter/material.dart';

class CircularProgressWidget extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;

  const CircularProgressWidget({
    super.key,
    required this.progress,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.2),
            color: color,
            strokeWidth: 4,
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: color,
                fontSize: size * 0.25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 
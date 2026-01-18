import 'package:flutter/material.dart';

class ProgramData {
  static final Map<String, List<Map<String, dynamic>>> exercises = {
    'Jog': [
      {
        'name': 'Warm-up Walk',
        'description': 'Light walking to prepare for jogging',
        'duration': '5 min',
        'sets': '1',
      },
      {
        'name': 'Light Jog',
        'description': 'Easy pace jogging',
        'duration': '10 min',
        'sets': '1',
      },
      {
        'name': 'Speed Intervals',
        'description': 'Alternating between fast and slow jogging',
        'duration': '15 min',
        'sets': '3',
      },
      {
        'name': 'Cool Down',
        'description': 'Slow jog followed by walking',
        'duration': '5 min',
        'sets': '1',
      },
    ],
    'Yoga': [
      {
        'name': 'Sun Salutation',
        'description': 'Traditional yoga warm-up sequence',
        'duration': '10 min',
        'sets': '3',
      },
      {
        'name': 'Warrior Poses',
        'description': 'Series of standing strength poses',
        'duration': '15 min',
        'sets': '2',
      },
      {
        'name': 'Balance Series',
        'description': 'Tree pose, eagle pose, and dancer pose',
        'duration': '10 min',
        'sets': '2',
      },
      {
        'name': 'Final Relaxation',
        'description': 'Meditation and breathing exercises',
        'duration': '5 min',
        'sets': '1',
      },
    ],
    'Cycling': [
      {
        'name': 'Warm-up Spin',
        'description': 'Light cycling to warm up muscles',
        'duration': '5 min',
        'sets': '1',
      },
      {
        'name': 'Hill Climbs',
        'description': 'Increased resistance cycling',
        'duration': '15 min',
        'sets': '3',
      },
      {
        'name': 'Sprint Intervals',
        'description': 'High-intensity speed bursts',
        'duration': '10 min',
        'sets': '4',
      },
      {
        'name': 'Cool Down Ride',
        'description': 'Easy pace to normalize heart rate',
        'duration': '5 min',
        'sets': '1',
      },
    ],
    'Workout': [
      {
        'name': 'Dynamic Stretching',
        'description': 'Full body mobility exercises',
        'duration': '5 min',
        'sets': '1',
      },
      {
        'name': 'Push-ups',
        'description': 'Upper body strength training',
        'duration': '10 min',
        'sets': '3',
      },
      {
        'name': 'Squats',
        'description': 'Lower body strength training',
        'duration': '10 min',
        'sets': '3',
      },
      {
        'name': 'Planks',
        'description': 'Core stability exercise',
        'duration': '5 min',
        'sets': '3',
      },
      {
        'name': 'Burpees',
        'description': 'Full body cardio exercise',
        'duration': '10 min',
        'sets': '3',
      },
    ],
  };

  static IconData getIconForProgram(String programName) {
    switch (programName) {
      case 'Jog':
        return Icons.directions_run;
      case 'Yoga':
        return Icons.self_improvement;
      case 'Cycling':
        return Icons.directions_bike;
      case 'Workout':
        return Icons.fitness_center;
      default:
        return Icons.sports;
    }
  }
} 
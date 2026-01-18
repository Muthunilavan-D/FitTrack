import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/circular_progress_widget.dart';
import '../widgets/program_card.dart';
import '../widgets/water_intake_widget.dart';
import '../providers/workout_progress_provider.dart';
import '../services/firebase_service.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _steps = 0;
  bool _isCountingSteps = false;
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final _activityController = TextEditingController();
  final _durationController = TextEditingController();
  bool _isLoading = false;
  int _totalCalories = 0;
  int _totalProtein = 0;
  int _totalSteps = 0;
  int _waterIntake = 0;
  int _workoutProgress = 0;
  int _totalWorkouts = 0;

  @override
  void initState() {
    super.initState();
    _loadTodaysData();
    initStepCounting();
  }

  Future<void> _loadTodaysData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final userRef = _firestore.collection('users').doc(user.uid);

    // Listen to nutrition history changes
    userRef
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

    // Listen to steps changes
    userRef.collection('daily_stats').doc(today).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _totalSteps = snapshot.data()?['steps'] ?? 0;
        });
      }
    });

    // Listen to water intake changes
    userRef
        .collection('water_intake')
        .doc(today)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _waterIntake = snapshot.data()?['amount'] ?? 0;
        });
      }
    });

    // Listen to workout progress changes
    userRef
        .collection('workoutProgress')
        .doc(today)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _workoutProgress =
              snapshot.data()?['completedExercises']?.length ?? 0;
          _totalWorkouts = snapshot.data()?['totalExercises'] ?? 0;
        });
      }
    });
  }

  void initStepCounting() {
    accelerometerEvents.listen((AccelerometerEvent event) async {
      if (!_isCountingSteps && event.y.abs() > 12) {
        setState(() {
          _steps++;
          _totalSteps++;
          _isCountingSteps = true;
        });

        // Update steps in Firestore
        final user = _auth.currentUser;
        if (user != null) {
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('daily_stats')
              .doc(today)
              .set({
            'steps': _totalSteps,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else if (event.y.abs() < 6) {
        _isCountingSteps = false;
      }
    });
  }

  Future<void> _addActivity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final activity = _activityController.text.trim();
      final duration = int.parse(_durationController.text.trim());
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('activities')
          .add({
        'activity': activity,
        'duration': duration,
        'date': date,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _activityController.clear();
      _durationController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity added successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding activity: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
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
                      Icons.directions_run,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activity Tracker',
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
                          'Monitor your daily progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Modern Stats Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.15,
                children: [
                  _buildModernStatCard(
                    'Total Calories',
                    '$_totalCalories',
                    'kcal',
                    Icons.local_fire_department,
                    Colors.orange,
                  ),
                  _buildModernStatCard(
                    'Steps',
                    '$_totalSteps',
                    '',
                    Icons.directions_walk,
                    Colors.blue,
                  ),
                  _buildModernStatCard(
                    'Total Protein',
                    '$_totalProtein',
                    'g',
                    Icons.fitness_center,
                    Colors.green,
                  ),
                  _buildModernStatCard(
                    'Water Intake',
                    '${_waterIntake}',
                    'ml',
                    Icons.water_drop,
                    Colors.cyan,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Water Intake Section
              const WaterIntakeWidget(),

              const SizedBox(height: 20),

              // Workout Progress
              Consumer<WorkoutProgressProvider>(
                builder: (context, workoutProvider, child) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Workout Progress',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${workoutProvider.remainingExercises} exercises left',
                              style: TextStyle(
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        CircularProgressWidget(
                          progress: workoutProvider.progressPercentage,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Programs Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple[400]!, Colors.purple[600]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Workout Programs',
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
              Container(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ProgramCard(
                        icon: Icons.directions_run,
                        label: 'Jog',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ProgramCard(
                        icon: Icons.self_improvement,
                        label: 'Yoga',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ProgramCard(
                        icon: Icons.directions_bike,
                        label: 'Cycling',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ProgramCard(
                        icon: Icons.fitness_center,
                        label: 'Workout',
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Add Activity Form
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
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green[400]!,
                                    Colors.green[600]!
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Add New Activity',
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
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800]!.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[700]!.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: TextFormField(
                            controller: _activityController,
                            decoration: InputDecoration(
                              labelText: 'Activity Name',
                              labelStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: const Icon(Icons.directions_run,
                                  color: Colors.blue),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(20),
                            ),
                            style: const TextStyle(color: Colors.white),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an activity name';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800]!.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[700]!.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: TextFormField(
                            controller: _durationController,
                            decoration: InputDecoration(
                              labelText: 'Duration (minutes)',
                              labelStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: const Icon(Icons.timer_outlined,
                                  color: Colors.blue),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(20),
                            ),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter duration';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [Colors.blue[400]!, Colors.blue[600]!],
                            ),
                            boxShadow: [
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
                              onTap: _isLoading ? null : _addActivity,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                alignment: Alignment.center,
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      )
                                    : const Text(
                                        'Add Activity',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Recent Activities
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[400]!, Colors.orange[600]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.history,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Recent Activities',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('users')
                    .doc(_auth.currentUser?.uid)
                    .collection('activities')
                    .orderBy('timestamp', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Error loading activities');
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final activities = snapshot.data!.docs;

                  if (activities.isEmpty) {
                    return const Center(
                      child: Text('No activities recorded yet'),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final activity =
                          activities[index].data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.directions_run),
                          title: Text(
                            activity['activity'] ?? 'Unknown activity',
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${activity['duration']} minutes • ${activity['date']}',
                            style: TextStyle(color: Colors.grey[400]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatCard(
      String label, String value, String unit, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
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
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _activityController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}

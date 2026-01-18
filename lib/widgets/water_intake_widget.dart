import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/water_intake_provider.dart';
import 'circular_progress_widget.dart';

class WaterIntakeWidget extends StatelessWidget {
  const WaterIntakeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WaterIntakeProvider>(
      builder: (context, waterProvider, child) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (waterProvider.isGoalAchieved) ...[
                const Center(
                  child: Icon(
                    Icons.celebration,
                    color: Colors.amber,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Daily Goal Achieved! 🎉',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Great job staying hydrated!',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.water_drop,
                        color: Colors.blue[300],
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Water Intake',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Remaining: ${waterProvider.remainingWater.toStringAsFixed(1)}L',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  CircularProgressWidget(
                    progress: waterProvider.progressPercentage,
                    color: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _WaterButton(
                      amount: 0.1,
                      label: '100ml',
                      onTap: () => waterProvider.addWater(0.1),
                    ),
                    const SizedBox(width: 8),
                    _WaterButton(
                      amount: 0.25,
                      label: '250ml',
                      onTap: () => waterProvider.addWater(0.25),
                    ),
                    const SizedBox(width: 8),
                    _CustomWaterButton(
                      onAdd: (amount) => waterProvider.addWater(amount),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WaterButton extends StatelessWidget {
  final double amount;
  final String label;
  final VoidCallback onTap;

  const _WaterButton({
    required this.amount,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.blue.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.add,
              color: Colors.blue,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomWaterButton extends StatelessWidget {
  final Function(double) onAdd;

  const _CustomWaterButton({
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCustomAmountDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.blue.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.edit,
              color: Colors.blue,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'Custom',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomAmountDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Add Custom Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Amount (ml)',
                labelStyle: TextStyle(color: Colors.blue),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter amount in milliliters (ml)',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                onAdd(amount / 1000); // Convert ml to L
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Add',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}

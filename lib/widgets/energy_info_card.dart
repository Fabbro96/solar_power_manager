import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EnergyInfoCard extends StatelessWidget {
  final String label;
  final String value;

  const EnergyInfoCard({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.value),
        ],
      ),
    );
  }
}

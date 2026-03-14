import 'package:flutter/material.dart';

class IpWarningBar extends StatelessWidget {
  final String reason;
  final VoidCallback onChangeIp;

  const IpWarningBar({
    super.key,
    required this.reason,
    required this.onChangeIp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.withAlpha(30),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$reason — check the inverter IP address.',
              style: const TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onChangeIp,
            child: const Text(
              'Change IP',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

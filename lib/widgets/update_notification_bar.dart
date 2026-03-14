import 'package:flutter/material.dart';

class UpdateNotificationBar extends StatelessWidget {
  final String tagName;
  final VoidCallback onDismiss;
  final VoidCallback onDownload;

  const UpdateNotificationBar({
    super.key,
    required this.tagName,
    required this.onDismiss,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.blue.withAlpha(30),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_download, color: Colors.blue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Version $tagName available',
                  style: const TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: onDismiss,
                child: const Text(
                  'Dismiss',
                  style: TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: onDownload,
                child: const Text(
                  'Download',
                  style: TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

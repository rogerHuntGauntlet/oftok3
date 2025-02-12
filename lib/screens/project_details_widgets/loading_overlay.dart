import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final double uploadProgress;

  const LoadingOverlay({
    super.key,
    required this.uploadProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: uploadProgress,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Uploading: ${(uploadProgress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
} 
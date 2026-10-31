import 'package:flutter/material.dart';

import 'empty_state.dart';

class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String title;

  const ErrorRetry({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Something went wrong',
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: title,
      message: message,
      actionLabel: 'Try again',
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
      isError: true,
    );
  }
}

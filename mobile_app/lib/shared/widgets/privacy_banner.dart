import 'package:flutter/material.dart';

/// Shown on Import when the backend's PARSER_MODE means a statement could
/// leave the machine. The project's headline claim is "100% offline" —
/// this is the one place the UI has to tell the truth about when it isn't.
class PrivacyBanner extends StatefulWidget {
  final String providerName;

  const PrivacyBanner({super.key, required this.providerName});

  @override
  State<PrivacyBanner> createState() => _PrivacyBannerState();
}

class _PrivacyBannerState extends State<PrivacyBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Statements are sent to ${widget.providerName} for parsing.')),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _dismissed = true),
          ),
        ],
      ),
    );
  }
}

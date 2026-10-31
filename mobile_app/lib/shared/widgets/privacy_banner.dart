import 'package:flutter/material.dart';

import 'inline_note.dart';

/// Shown on Import when the backend's PARSER_MODE means a statement could
/// leave the machine. The project's headline claim is "100% offline", and
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
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _dismissed
          ? const SizedBox(width: double.infinity)
          : InlineNote(
              icon: Icons.cloud_upload_outlined,
              message: 'Statements are sent to ${widget.providerName} for parsing.',
              onDismiss: () => setState(() => _dismissed = true),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/txa_settings.dart';
import 'dart:convert';

class TxaWatermark extends StatelessWidget {
  final Widget child;
  final bool show;

  const TxaWatermark({super.key, required this.child, this.show = true});

  @override
  Widget build(BuildContext context) {
    if (!show) return child;

    // Get user email for extra security if logged in
    String? userIdentifier;
    try {
      if (TxaSettings.userData.isNotEmpty) {
        final userData = jsonDecode(TxaSettings.userData);
        userIdentifier = userData['email'] ?? userData['name'];
      }
    } catch (_) {}

    return Stack(
      children: [
        child,
        // Logo watermark at bottom left
        Positioned(
          bottom: 20,
          left: 20,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.15, // Visible but subtle
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 60,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ),
                  if (userIdentifier != null)
                    Text(
                      userIdentifier,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

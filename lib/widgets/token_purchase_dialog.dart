import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_service.dart';

class TokenPurchaseDialog extends StatefulWidget {
  const TokenPurchaseDialog({super.key});

  @override
  State<TokenPurchaseDialog> createState() => _TokenPurchaseDialogState();
}

class _TokenPurchaseDialogState extends State<TokenPurchaseDialog> {
  final UserService _userService = UserService();
  bool _isLoading = false;

  Future<void> _requestTokens() async {
    final currentUser = await _userService.getCurrentUser();
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to request tokens'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'begin@ideatrek.io',
      queryParameters: {
        'subject': 'Token Request for OHFtok',
        'body': 'Hello,\n\nI would like to request more tokens for my account.\n\n'
                'User Details:\n'
                'Email: ${currentUser.email}\n'
                'Current Token Balance: ${currentUser.tokens}\n\n'
                'Thank you!'
      }
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
        if (mounted) {
          Navigator.of(context).pop(); // Close the dialog after sending
        }
      } else {
        throw 'Could not launch email client';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Request Tokens',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Click the button below to send an email requesting more tokens for your account.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _requestTokens,
              icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.email),
              label: const Text('Request Tokens'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
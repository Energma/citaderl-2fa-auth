import 'package:flutter/material.dart';
import '../widgets/pin_input.dart';

/// PIN setup screen that handles creation and confirmation of a new PIN.
/// Returns the confirmed PIN string via Navigator.pop, or null if cancelled.
class PinSetupScreen extends StatefulWidget {
  final String title;

  const PinSetupScreen({super.key, this.title = 'Set Up PIN'});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _firstPin;
  String? _error;

  void _onPinEntered(String pin) {
    if (_firstPin == null) {
      // First entry
      setState(() {
        _firstPin = pin;
        _error = null;
      });
    } else {
      // Confirmation
      if (pin == _firstPin) {
        Navigator.pop(context, pin);
      } else {
        setState(() {
          _firstPin = null;
          _error = 'PINs do not match. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: PinInput(
            onCompleted: _onPinEntered,
            error: _error,
            title: _firstPin == null ? 'Create PIN' : 'Confirm PIN',
            subtitle: _firstPin == null
                ? 'Choose a 6-digit PIN'
                : 'Enter the same PIN again',
          ),
        ),
      ),
    );
  }
}

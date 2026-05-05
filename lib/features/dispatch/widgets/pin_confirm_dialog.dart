import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class PinConfirmDialog extends StatefulWidget {
  const PinConfirmDialog({super.key, required this.expectedPin});
  final String expectedPin;

  @override
  State<PinConfirmDialog> createState() => _PinConfirmDialogState();
}

class _PinConfirmDialogState extends State<PinConfirmDialog> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String? _error;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 4; i++) {
      final index = i;
      _focusNodes[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[index].text.isEmpty &&
            index > 0) {
          _focusNodes[index - 1].requestFocus();
          _controllers[index - 1].clear();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _error = null);

    final entered = _controllers.map((c) => c.text).join();
    if (entered.length == 4 && _controllers.every((c) => c.text.isNotEmpty)) {
      Future.delayed(const Duration(milliseconds: 100), _confirm);
    }
  }

  void _confirm() {
    final entered = _controllers.map((c) => c.text).join();
    if (entered.length < 4) {
      setState(() => _error = 'Please enter all 4 digits.');
      return;
    }
    if (entered != widget.expectedPin) {
      setState(() {
        _error = 'Incorrect last 4 digits.';
        for (final c in _controllers) {
          c.clear();
        }
      });
      _focusNodes[0].requestFocus();
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
      child: Padding(
        padding: EdgeInsets.all(DSSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: DSIconSize.xl,
              color: DSColors.primary,
            ),
            DSSpacing.hMd,
            Text(
              'CONFIRM ACCEPTANCE',
              style: DSTypography.heading().copyWith(
                fontWeight: FontWeight.w800,
                fontSize: DSTypography.sizeMd,
                letterSpacing: DSTypography.lsLoose,
              ),
            ),
            DSSpacing.hSm,
            Text(
              'ENTER LAST 4 DIGITS OF DISPATCH CODE TO CONFIRM',
              textAlign: TextAlign.center,
              style: DSTypography.body(color: DSColors.labelSecondary).copyWith(
                fontSize: DSTypography.sizeSm,
                letterSpacing: DSTypography.lsLoose,
              ),
            ),
            DSSpacing.hLg,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: TextFormField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: DSStyles.cardRadius,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: DSStyles.cardRadius,
                        borderSide: const BorderSide(
                          color: DSColors.primary,
                          width: DSStyles.strokeWidth,
                        ),
                      ),
                    ),
                    style: DSTypography.heading().copyWith(
                      fontSize: 24.0,
                      fontWeight: FontWeight.w900,
                    ),
                    onChanged: (v) => _onDigitChanged(i, v),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              DSSpacing.hSm,
              Text(
                _error!,
                style: DSTypography.body(
                  color: DSColors.error,
                ).copyWith(fontSize: DSTypography.sizeSm),
                textAlign: TextAlign.center,
              ),
            ],
            DSSpacing.hLg,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('CANCEL'),
                  ),
                ),
                DSSpacing.wMd,
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: DSColors.primary,
                    ),
                    onPressed: _confirm,
                    child: const Text('CONFIRM'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

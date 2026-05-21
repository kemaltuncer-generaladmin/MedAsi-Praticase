import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/praticase_colors.dart';

class OtpInput extends StatefulWidget {
  const OtpInput({required this.onChanged, super.key});

  final ValueChanged<String> onChanged;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());

  void _emit() {
    widget.onChanged(_controllers.map((item) => item.text).join());
  }

  void _handleChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      for (var offset = 0; offset < digits.length; offset++) {
        final target = index + offset;
        if (target >= _controllers.length) break;
        _controllers[target].text = digits[offset];
      }
      final nextIndex = (index + digits.length).clamp(0, _nodes.length - 1);
      _nodes[nextIndex].requestFocus();
      _controllers[nextIndex].selection = TextSelection.collapsed(
        offset: _controllers[nextIndex].text.length,
      );
      _emit();
      return;
    }

    if (digits != value) {
      _controllers[index].text = digits;
      _controllers[index].selection = TextSelection.collapsed(
        offset: digits.length,
      );
    }
    if (digits.isNotEmpty && index < _nodes.length - 1) {
      _nodes[index + 1].requestFocus();
    }
    if (digits.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    _emit();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < _controllers.length; index++) ...[
          Expanded(
            child: TextField(
              controller: _controllers[index],
              focusNode: _nodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              textInputAction: index == 5
                  ? TextInputAction.done
                  : TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                filled: true,
                fillColor: PratiCaseColors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: PratiCaseColors.border),
                ),
              ),
              onChanged: (value) => _handleChanged(index, value),
            ),
          ),
          if (index != 5) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

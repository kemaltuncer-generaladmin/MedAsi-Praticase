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
              textInputAction: index == 5
                  ? TextInputAction.done
                  : TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              decoration: InputDecoration(
                filled: true,
                fillColor: PratiCaseColors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: PratiCaseColors.border),
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty && index < _nodes.length - 1) {
                  _nodes[index + 1].requestFocus();
                }
                if (value.isEmpty && index > 0) {
                  _nodes[index - 1].requestFocus();
                }
                widget.onChanged(_controllers.map((item) => item.text).join());
              },
            ),
          ),
          if (index != 5) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

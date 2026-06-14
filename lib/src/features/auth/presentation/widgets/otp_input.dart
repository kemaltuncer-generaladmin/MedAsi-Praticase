import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 280;
        final gap = isNarrow ? 6.0 : 8.0;
        final radius = isNarrow ? 10.0 : 12.0;
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
                    fillColor: const Color(0xFFF7FBFF),
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isNarrow ? 11 : 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radius),
                      borderSide: const BorderSide(color: Color(0xFFC7DCF3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radius),
                      borderSide: const BorderSide(color: Color(0xFFC7DCF3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radius),
                      borderSide: const BorderSide(
                        color: Color(0xFF1D67D2),
                        width: 1.4,
                      ),
                    ),
                  ),
                  maxLength: 1,
                  style: TextStyle(
                    color: const Color(0xFF102033),
                    fontSize: isNarrow ? 17 : 18,
                    fontWeight: FontWeight.w900,
                  ),
                  onChanged: (value) => _handleChanged(index, value),
                ),
              ),
              if (index != 5) SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

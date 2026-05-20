import 'package:flutter/material.dart';

import 'auth_visuals.dart';

class AuthBrand extends StatelessWidget {
  const AuthBrand({this.centered = true, super.key});

  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: const AuthWordmark(width: 252),
    );
  }
}

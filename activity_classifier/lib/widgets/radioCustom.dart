import 'package:flutter/material.dart';

class RadioCustom extends StatelessWidget {
  const RadioCustom({super.key, required this.text, required this.value, required this.onTap, required this.groupValue});

  final String text;
  final String value;
  final String groupValue;
  final Function(String?) onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Radio(value: value, groupValue: groupValue, onChanged: onTap),
        Text(text),
      ],
    );
  }
}

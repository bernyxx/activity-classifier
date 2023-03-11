import 'package:flutter/material.dart';

class DataWidget extends StatelessWidget {
  const DataWidget(this.title, this.data, {super.key});

  final String title;
  final List<int> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Card(
        child: ListTile(
          title: Text('$title: $data'),
          tileColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}

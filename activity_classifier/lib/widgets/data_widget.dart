import 'package:flutter/material.dart';

// widget to display the data collected of a single feature
class DataWidget extends StatelessWidget {
  const DataWidget(this.title, this.data, {super.key});

  // name of the feature
  final String title;

  // list of the data collected
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

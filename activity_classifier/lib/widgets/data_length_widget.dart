import 'package:flutter/material.dart';

// display how many samples are collected without displaying the actual data
// similar to DataWidget but shows only how  many samples are collected
class DataLengthWidget extends StatelessWidget {
  const DataLengthWidget(this.title, this.data, {super.key});

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
          title: Text('$title: ${data.length} samples'),
          tileColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}

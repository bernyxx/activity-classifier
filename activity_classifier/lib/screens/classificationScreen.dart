import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'dart:math';

class ClassificationScreen extends StatefulWidget {
  const ClassificationScreen({super.key});

  @override
  State<ClassificationScreen> createState() => _ClassificationScreenState();
}

class _ClassificationScreenState extends State<ClassificationScreen> {
  String activity = '';

  Future<void> runModel() async {
    final interpreter = await tfl.Interpreter.fromAsset('activity_classifier.tflite');

    var input = List.filled(6 * 20, 0.5).reshape([1, 20, 6]);
    var output = [
      [0.0, 0.0, 0.0]
    ];

    interpreter.run(input, output);
    print(output);

    int indexResult = output[0].indexOf(output[0].reduce(max));
    print(indexResult);

    String activityRes = '';

    switch (indexResult) {
      case 0:
        activityRes = 'Running';
        break;
      case 1:
        activityRes = 'Still';
        break;
      default:
        activityRes = 'Walking';
    }

    setState(() {
      activity = activityRes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 30, horizontal: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'CLASSIFY ACTIVITY',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: runModel,
              child: const Text('Run Model'),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Activity: $activity',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

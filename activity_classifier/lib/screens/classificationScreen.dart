import 'package:activity_classifier/providers/BLEProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'dart:math';

class ClassificationScreen extends StatefulWidget {
  const ClassificationScreen({super.key});

  @override
  State<ClassificationScreen> createState() => _ClassificationScreenState();
}

class _ClassificationScreenState extends State<ClassificationScreen> {
  String activity = '';

  void showErrorSnackbar(BuildContext ctx, String errorMsg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(errorMsg),
        backgroundColor: Colors.red,
      ),
    );
  }

  IconData getActivityIcon() {
    switch (activity) {
      case 'Still':
        return Icons.man;
      case 'Walking':
        return Icons.directions_walk;
      case 'Running':
        return Icons.directions_run;
      default:
        return Icons.do_not_disturb_alt_sharp;
    }
  }

  Future<void> runModel(BuildContext ctx, List<List<int>> data, int evaluations) async {
    int inputFeatureSize = 20;

    List<int> result = [];

    if (data.isEmpty) {
      print('No data');
      showErrorSnackbar(ctx, 'No data collected');
      return;
    }

    // check if every feature has at least the number of samples required to run the model

    int minFeatureSize = data.map((feature) => feature.length).toList().reduce(min);

    if (minFeatureSize < 20) {
      print('Not enough data');
      showErrorSnackbar(ctx, 'Not enough data to run the classifier!');
      return;
    }

    final interpreter = await tfl.Interpreter.fromAsset('activity_classifier.tflite');

    List<List<double>> input = [];

    for (int featureIndex = 0; featureIndex < 6; featureIndex++) {
      int featureLength = data[featureIndex].length;

      // retain the last 20 samples
      List<int> dataFeature = data[featureIndex].sublist(featureLength - inputFeatureSize);

      for (int i = 0; i < dataFeature.length; i++) {
        if (featureIndex == 0) {
          input.add([]);
        }

        // arduino scaler, creo uno scaler in base ai massimi valori registrabili da accelerometro
        // e giroscopio
        double res = 0.0;
        if (featureIndex < 3) {
          res = (dataFeature[i] + 4000.0) / 8000.0;
        } else {
          res = (dataFeature[i] + 2000000.0) / 4000000.0;
        }

        input[i].add(res);
      }
    }

    var output = [
      [0.0, 0.0, 0.0]
    ];

    interpreter.run([input], output);

    // print classification probability
    print(output);

    int indexResult = output[0].indexOf(output[0].reduce(max));

    // print the class with the highest probability
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
    return Consumer<BLEProvider>(
      builder: (context, bleProvider, child) {
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
                const Text(
                  'Tap the scan button to start searching for the Arduino Nano 33 BLE Sense and start receiving the data',
                  textAlign: TextAlign.left,
                ),
                const SizedBox(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: (bleProvider.connection == null && bleProvider.isScanning == false) ? () => bleProvider.scan(context) : null,
                      child: const Text('Scan'),
                    ),
                    ElevatedButton(
                      onPressed: (bleProvider.connection == null) ? null : bleProvider.stop,
                      child: const Text('Stop'),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                Text('Board status: ${bleProvider.connection != null ? bleProvider.getDeviceConnectionStateString(bleProvider.connectionState) : 'Disconnected'}'),
                const SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed: () => runModel(context, bleProvider.measures, 1),
                  child: const Text('Classify'),
                ),
                const SizedBox(
                  height: 10,
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          getActivityIcon(),
                          size: 120,
                        ),
                        const SizedBox(
                          height: 30,
                        ),
                        Text(
                          activity != '' ? activity : 'No Data Collected',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

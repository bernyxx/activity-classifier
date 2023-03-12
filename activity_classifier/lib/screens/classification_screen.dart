import 'dart:async';
import 'package:activity_classifier/providers/ble_provider.dart';
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
  // result of the neural network model
  String activity = '';

  // number of samples collected when the classifier ran before
  int previousMeasuresLength = 0;

  // timer to execute the model every 3 seconds on the latest data collected
  Timer? timer;

  // start scan for boards and activate the timer to execute the NN model
  void startScanAndModel(BuildContext ctx) {
    previousMeasuresLength = 0;
    Provider.of<BLEProvider>(ctx, listen: false).scan(ctx);
    timer = Timer.periodic(const Duration(seconds: 3), (_) {
      runModel(ctx, Provider.of<BLEProvider>(context, listen: false).measures);
    });
  }

  // disconnect the board and stop the timer that executes the model periodically
  void stopScanAndModel(BuildContext ctx) {
    timer?.cancel();
    Provider.of<BLEProvider>(ctx, listen: false).stop();
    setState(() {
      activity = '';
    });
  }

  // show a red snackbar at the bottom of the screen
  void showErrorSnackbar(BuildContext ctx, String errorMsg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(errorMsg),
        backgroundColor: Colors.red,
      ),
    );
  }

  // return the icon associated with the activity recognised
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

  // run the model on the latest data collected
  Future<void> runModel(BuildContext ctx, List<List<int>> data) async {
    int inputFeatureSize = 20;

    // if no data collected return
    if (data.isEmpty) {
      // print('No data');
      return;
    }

    // check if every feature has at least the number of samples required to run the model
    int minFeatureSize = data.map((feature) => feature.length).toList().reduce(min);

    // not enough data collected to run the model, return
    if (minFeatureSize < 20) {
      // print('Not enough data');
      return;
    }

    // initialize an interpreter using the tflite model in the assets
    final interpreter = await tfl.Interpreter.fromAsset('activity_classifier.tflite');

    // initialize input list
    List<List<double>> input = [];

    // measures list is grouped by features but we need 20 rows and 6 columns
    // each row must contain the 6 features (xa, ya, za, xg, yg, zg)

    for (int featureIndex = 0; featureIndex < 6; featureIndex++) {
      int featureLength = data[featureIndex].length;

      // pick the last 20 samples
      List<int> dataFeature = data[featureIndex].sublist(featureLength - inputFeatureSize);

      // scale every sample in dataFeature list
      for (int i = 0; i < dataFeature.length; i++) {
        if (featureIndex == 0) {
          input.add([]);
        }

        // arduino scaler, scale the data between 0 and 1
        double res = 0.0;
        if (featureIndex < 3) {
          res = (dataFeature[i] + 4000.0) / 8000.0;
        } else {
          res = (dataFeature[i] + 2000000.0) / 4000000.0;
        }

        input[i].add(res);
      }
    }

    // initialize output
    var output = [
      [0.0, 0.0, 0.0]
    ];

    // run the model
    interpreter.run([input], output);

    // print classification probability
    // print(output);

    // the category with the highest probability
    int indexResult = output[0].indexOf(output[0].reduce(max));

    // print the class with the highest probability
    // print(indexResult);

    // result activity as string
    String activityRes = '';

    // return the activity recognised as string
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

    // update the UI
    setState(() {
      activity = activityRes;
    });
  }

  // stop the timer executing the model periodically if it is still running while disposing the screen
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
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
                      onPressed: (bleProvider.connection == null && bleProvider.isScanning == false) ? () => startScanAndModel(context) : null,
                      child: const Text('Scan'),
                    ),
                    ElevatedButton(
                      onPressed: (bleProvider.connection == null) ? null : () => stopScanAndModel(context),
                      child: const Text('Stop'),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                Text('Board Status: ${bleProvider.connection != null ? bleProvider.getDeviceConnectionStateString(bleProvider.connectionState) : 'Disconnected'}'),
                const SizedBox(
                  height: 20,
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
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

import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:activity_classifier/firebase_options.dart';
import 'package:activity_classifier/providers/ble_provider.dart';
import 'package:activity_classifier/widgets/data_length_widget.dart';
import 'package:activity_classifier/widgets/data_widget.dart';
import 'package:activity_classifier/widgets/radio_custom.dart';
import 'package:date_format/date_format.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class TakeAndSaveDataScreen extends StatefulWidget {
  const TakeAndSaveDataScreen({super.key});

  @override
  State<TakeAndSaveDataScreen> createState() => _TakeAndSaveDataScreenStateNew();
}

class _TakeAndSaveDataScreenStateNew extends State<TakeAndSaveDataScreen> {
  // check if firebase library is initilized
  bool isFirebaseInitialized = false;

  // switch on -> the values of the samples are showed
  // switch off -> only how many samples per characteristics are shown
  bool showData = false;

  // dataset type selection
  String datasetType = 'still';

  // labels of the characteristics
  List<String> labels = ['accX', 'accY', 'accZ', 'gyroX', 'gyroY', 'gyroZ', 'magX', 'magY', 'magZ', 'temp', 'hum'];

  // disconnect the streams connected on the ble characteristics, disconnect the board, write the measures on a csv file and upload it on a firebase storage bucket
  Future<void> stopTakeData() async {
    await Provider.of<BLEProvider>(context, listen: false).stop();

    // create a csv file with the collected data
    await writeDataToCsv();

    // upload the csv file to cloud
    await uploadFile();
  }

  // get the csv file saved
  Future<File> getFile() async {
    Directory? dir = await getExternalStorageDirectory();
    // print(dir!.path);
    return File('${dir!.path}/data.csv');
  }

  // take the measurements (list of measures) and create a csv file
  // save the file in the app folder in the device
  Future<void> writeDataToCsv() async {
    // get local reference (where to save the file)
    File file = await getFile();

    // csv index line
    String toFile = 'xa,ya,za,xg,yg,zg,xm,ym,zm,temp,hum\n';
    // String toFile = 'xa,ya,za\n';

    // measures = measures.sublist(0, 3);

    // ignore: use_build_context_synchronously
    if (!context.mounted) return;
    List<List<int>> measures = Provider.of<BLEProvider>(context, listen: false).measures;

    int minLength = measures.map((e) => e.length).toList().reduce(min);

    // iterate the measures
    for (int i = 0; i < minLength; i++) {
      String newLine = '';
      for (int featureIndex = 0; featureIndex < measures.length; featureIndex++) {
        if (featureIndex != measures.length - 1) {
          // if not last value of the measure put a comma
          newLine += '${measures[featureIndex][i]},';
        } else {
          // if last value of the measure put an end line
          newLine += '${measures[featureIndex][i]}\n';
        }
      }

      // add the line to the file string
      toFile += newLine;
    }

    // write the whole string to the file
    file.writeAsString(toFile);

    setState(() {
      measures.clear();
    });
  }

  // update the datasetType variable and update the UI
  void handleDatasetTypeSelector(String type, var setState) {
    setState(() {
      datasetType = type;
    });
  }

  // upload the csv file to Firebase Storage
  Future<void> uploadFile() async {
    // initialize firebase if not already initialized
    if (!isFirebaseInitialized) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      isFirebaseInitialized = true;
    }

    // remote bucket reference
    final storageRef = FirebaseStorage.instance.ref();

    // get the timestamp for unique file name
    final DateTime dt = DateTime.now();

    // format the date to get the date using the format day_month_year_hours_mins_secs
    final String timestamp = formatDate(dt, [dd, '_', mm, '_', yyyy, '_', HH, '_', nn, '_', ss]);

    datasetType = 'still';

    // show a dialog with a radio picker to select the type of the activity recorded
    // ignore: use_build_context_synchronously
    bool save = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Select the activity'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioCustom(
                  text: 'Still',
                  value: 'still',
                  groupValue: datasetType,
                  onTap: (value) => handleDatasetTypeSelector(value!, setState),
                ),
                RadioCustom(
                  text: 'Walking',
                  value: 'walking',
                  groupValue: datasetType,
                  onTap: (value) => handleDatasetTypeSelector(value!, setState),
                ),
                RadioCustom(
                  text: 'Running',
                  value: 'running',
                  groupValue: datasetType,
                  onTap: (value) => handleDatasetTypeSelector(value!, setState),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('DELETE'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );

    if (!save) {
      // print('trash the data');
      return;
    }

    // get remote file (Firebase File) reference
    final fileRef = storageRef.child('${datasetType}_$timestamp.csv');

    // get local file reference
    File file = await getFile();

    try {
      // upload local csv file to Firebase Storage
      await fileRef.putFile(file);

      // ignore: use_build_context_synchronously
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dataset upload successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print(e);
    }
  }

  // function to handle the switch (values or number of measures)
  void switchController(bool value) {
    setState(() {
      showData = value;
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
                  'UPLOAD A NEW DATASET',
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
                      onPressed: (bleProvider.connection == null) ? null : stopTakeData,
                      child: const Text('Stop'),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                Text('Board Status: ${bleProvider.connection != null ? bleProvider.getDeviceConnectionStateString(bleProvider.connectionState) : 'Disconnected'}'),
                const SizedBox(
                  height: 10,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const Text('Show Values'),
                    Switch(
                      value: showData,
                      onChanged: (value) => switchController(value),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    children: showData
                        ? [
                            DataWidget('accX', bleProvider.measures.isNotEmpty ? bleProvider.measures[0] : []),
                            DataWidget('accY', bleProvider.measures.isNotEmpty ? bleProvider.measures[1] : []),
                            DataWidget('accZ', bleProvider.measures.isNotEmpty ? bleProvider.measures[2] : []),
                            DataWidget('gyroX', bleProvider.measures.isNotEmpty ? bleProvider.measures[3] : []),
                            DataWidget('gyroY', bleProvider.measures.isNotEmpty ? bleProvider.measures[4] : []),
                            DataWidget('gyroZ', bleProvider.measures.isNotEmpty ? bleProvider.measures[5] : []),
                            DataWidget('magX', bleProvider.measures.isNotEmpty ? bleProvider.measures[6] : []),
                            DataWidget('magY', bleProvider.measures.isNotEmpty ? bleProvider.measures[7] : []),
                            DataWidget('magZ', bleProvider.measures.isNotEmpty ? bleProvider.measures[8] : []),
                            DataWidget('temp', bleProvider.measures.isNotEmpty ? bleProvider.measures[9] : []),
                            DataWidget('hum', bleProvider.measures.isNotEmpty ? bleProvider.measures[10] : []),
                          ]
                        : [
                            DataLengthWidget('accX', bleProvider.measures.isNotEmpty ? bleProvider.measures[0] : []),
                            DataLengthWidget('accY', bleProvider.measures.isNotEmpty ? bleProvider.measures[1] : []),
                            DataLengthWidget('accZ', bleProvider.measures.isNotEmpty ? bleProvider.measures[2] : []),
                            DataLengthWidget('gyroX', bleProvider.measures.isNotEmpty ? bleProvider.measures[3] : []),
                            DataLengthWidget('gyroY', bleProvider.measures.isNotEmpty ? bleProvider.measures[4] : []),
                            DataLengthWidget('gyroZ', bleProvider.measures.isNotEmpty ? bleProvider.measures[5] : []),
                            DataLengthWidget('magX', bleProvider.measures.isNotEmpty ? bleProvider.measures[6] : []),
                            DataLengthWidget('magY', bleProvider.measures.isNotEmpty ? bleProvider.measures[7] : []),
                            DataLengthWidget('magZ', bleProvider.measures.isNotEmpty ? bleProvider.measures[8] : []),
                            DataLengthWidget('temp', bleProvider.measures.isNotEmpty ? bleProvider.measures[9] : []),
                            DataLengthWidget('hum', bleProvider.measures.isNotEmpty ? bleProvider.measures[10] : []),
                          ],
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

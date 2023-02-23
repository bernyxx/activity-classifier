import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:activity_classifier/firebase_options.dart';
import 'package:activity_classifier/widgets/dataLengthWidget.dart';
import 'package:activity_classifier/widgets/dataWidget.dart';
import 'package:activity_classifier/widgets/radioCustom.dart';
import 'package:date_format/date_format.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:location_permissions/location_permissions.dart';
import 'package:path_provider/path_provider.dart';

class TakeAndSaveDataScreen extends StatefulWidget {
  const TakeAndSaveDataScreen({super.key});

  @override
  State<TakeAndSaveDataScreen> createState() => _TakeAndSaveDataScreenState();
}

class _TakeAndSaveDataScreenState extends State<TakeAndSaveDataScreen> {
  bool isFirebaseInitialized = false;

  bool isScanning = false;

  final flutterReactiveBle = FlutterReactiveBle();

  late StreamSubscription<DiscoveredDevice>? scanStream;

  StreamSubscription<ConnectionStateUpdate>? connection;

  DeviceConnectionState connectionState = DeviceConnectionState.disconnected;

  // 2 BLE services
  final Uuid environmentalSensingService = Uuid.parse("181A");
  final Uuid accelerometerService = Uuid.parse("1101");

  // list of BLE characteristics

  final Uuid accXCharacteristic = Uuid.parse("2101");
  final Uuid accYCharacteristic = Uuid.parse("2102");
  final Uuid accZCharacteristic = Uuid.parse("2103");

  final Uuid gyroXCharacteristic = Uuid.parse("2201");
  final Uuid gyroYCharacteristic = Uuid.parse("2202");
  final Uuid gyroZCharacteristic = Uuid.parse("2203");

  final Uuid magXCharacteristic = Uuid.parse("2301");
  final Uuid magYCharacteristic = Uuid.parse("2302");
  final Uuid magZCharacteristic = Uuid.parse("2303");

  final Uuid temperatureCharacteristic = Uuid.parse("2A6E");
  final Uuid humidityCharacteristic = Uuid.parse("2A6F");

  bool showData = false;

  List<StreamSubscription<dynamic>> streams = [];

  // list of measures
  List<List<int>> measures = [];

  // dataset type
  String datasetType = 'still';

  List<String> labels = ['accX', 'accY', 'accZ', 'gyroX', 'gyroY', 'gyroZ', 'magX', 'magY', 'magZ', 'temp', 'hum'];

  List<QualifiedCharacteristic> characteristics = [];

  // cast the list of bytes to an int32
  int toSignedInt(List<int> bytes) {
    Int8List numbyte = Int8List.fromList(bytes);

    return numbyte.buffer.asInt32List()[0];
  }

  // function called when a discovered device is selected from the list during scanning
  void selectDevice(DiscoveredDevice device) async {
    print("selected device!");
    Navigator.of(context).pop();
    scanStream!.cancel();
    await connectAndGetData(device);
  }

  // scan BLE devices
  void scan(BuildContext ctx) async {
    List<DiscoveredDevice> foundDevices = [];
    var navigator = Navigator.of(ctx);
    var messenger = ScaffoldMessenger.of(ctx);

    PermissionStatus permission = await LocationPermissions().requestPermissions();

    if (permission == PermissionStatus.granted) {
      setState(() {
        isScanning = true;
      });

      // show a dialog with a list of the BLE devices offering "1101" and "181A" services
      // ignore: use_build_context_synchronously
      showDialog(
        barrierDismissible: false,
        context: ctx,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              scanStream = flutterReactiveBle.scanForDevices(
                withServices: [accelerometerService, environmentalSensingService],
              ).listen((device) async {
                // check if the device was already discovered
                if (foundDevices.indexWhere((element) => element.id == device.id) == -1) {
                  // if not already discovered, add it to the list of discovered devices
                  setState(() {
                    foundDevices.add(device);
                    print('added ${device.name}');
                  });
                }
              }, onError: (err) => print(err));
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: const [
                        CircularProgressIndicator(),
                        Text('Looking for boards nearby...'),
                      ],
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    Flexible(
                      child: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: foundDevices.length,
                          itemBuilder: (context, index) {
                            return ElevatedButton(
                              onPressed: () => selectDevice(foundDevices[index]),
                              child: Text(foundDevices[index].name),
                            );
                          },
                        ),
                      ),
                    )
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      navigator.pop();
                      scanStream!.cancel();
                      setState(() {
                        isScanning = false;
                        connection = null;
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        },
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Scanning for BLE Peripherals require location permissions!'),
        ),
      );
    }
  }

  // disconnect the board
  Future<void> stop() async {
    print("disconnecting board");

    // stop receiving data for all characteristics
    for (StreamSubscription stream in streams) {
      await stream.cancel();
    }

    // disconnect the board
    await connection!.cancel();

    setState(() {
      // clear connection
      connection = null;
    });

    // create a csv file with the collected data
    await writeDataToCsv();

    // upload the csv file to cloud
    await uploadFile();
  }

  // connect to the selected board and get the data
  Future<void> connectAndGetData(DiscoveredDevice device) async {
    // connect to the device Nano Suino
    Stream<ConnectionStateUpdate> currentConnectionStream = flutterReactiveBle.connectToDevice(
      id: device.id,
      connectionTimeout: const Duration(seconds: 5),
    );

    // listen for connection status changes
    connection = currentConnectionStream.listen(
      (event) {
        // print the changes
        print(event);
        setState(() {
          connectionState = event.connectionState;
        });
      },
    );

    // better to make isScanning false here because between there is an interval between the time when the device is found and the time
    // when the app is connected to the nano

    setState(() {
      isScanning = false;
    });

    // list of characteristics

    final qAccXCharacteristic = QualifiedCharacteristic(deviceId: device.id, serviceId: accelerometerService, characteristicId: accXCharacteristic);
    final qAccYCharacteristic = QualifiedCharacteristic(deviceId: device.id, serviceId: accelerometerService, characteristicId: accYCharacteristic);
    final qAccZCharacteristic = QualifiedCharacteristic(deviceId: device.id, serviceId: accelerometerService, characteristicId: accZCharacteristic);

    final qGyroXCharacteristic = QualifiedCharacteristic(deviceId: device.id, serviceId: accelerometerService, characteristicId: gyroXCharacteristic);
    final qGyroYCharacteristic = QualifiedCharacteristic(deviceId: device.id, serviceId: accelerometerService, characteristicId: gyroYCharacteristic);
    final qGyroZCharacteristic = QualifiedCharacteristic(deviceId: device.id, serviceId: accelerometerService, characteristicId: gyroZCharacteristic);

    final qMagXCharacteristic = QualifiedCharacteristic(deviceId: device.id, serviceId: accelerometerService, characteristicId: magXCharacteristic);
    final qMagYCharacteristic = QualifiedCharacteristic(deviceId: device.id, serviceId: accelerometerService, characteristicId: magYCharacteristic);
    final qMagZCharacteristic = QualifiedCharacteristic(deviceId: device.id, serviceId: accelerometerService, characteristicId: magZCharacteristic);

    final qTemperatureCharacteristic = QualifiedCharacteristic(deviceId: device.id, serviceId: environmentalSensingService, characteristicId: temperatureCharacteristic);
    final qHumidityCharacteristic = QualifiedCharacteristic(deviceId: device.id, serviceId: environmentalSensingService, characteristicId: humidityCharacteristic);

    List<QualifiedCharacteristic> characteristics = [
      qAccXCharacteristic,
      qAccYCharacteristic,
      qAccZCharacteristic,
      qGyroXCharacteristic,
      qGyroYCharacteristic,
      qGyroZCharacteristic,
      qMagXCharacteristic,
      qMagYCharacteristic,
      qMagZCharacteristic,
      qTemperatureCharacteristic,
      qHumidityCharacteristic
    ];

    // initialize measures list
    for (var _ in characteristics) {
      measures.add([]);
    }

    // open connections to read on characteristics
    for (int i = 0; i < characteristics.length; i++) {
      streams.add(flutterReactiveBle.subscribeToCharacteristic(characteristics[i]).listen((data) {
        final int value = toSignedInt(data);
        setState(() {
          measures[i].add(value);
        });
      }));
    }
  }

  Future<File> getFile() async {
    Directory? dir = await getExternalStorageDirectory();
    print(dir!.path);
    return File('${dir.path}/data.csv');
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
      print('trash the data');
      return;
    }

    // get remote file (Firebase File) reference
    final fileRef = storageRef.child('${datasetType}_$timestamp.csv');

    // get local file reference
    File file = await getFile();

    try {
      // upload local csv file to Firebase Storage
      await fileRef.putFile(file);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dataset upload successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (e) {
      print(e);
    }
  }

  String getDeviceConnectionStateString() {
    if (connection == null) return 'Disconnected';

    switch (connectionState) {
      case DeviceConnectionState.disconnected:
        return 'Disconnected';
      case DeviceConnectionState.connected:
        return 'Connected';
      case DeviceConnectionState.connecting:
        return 'Connecting';
      case DeviceConnectionState.disconnecting:
        return 'Disconnecting';
      default:
        return '';
    }
  }

  void switchController(bool value) {
    setState(() {
      showData = value;
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
                  onPressed: (connection == null && isScanning == false) ? () => scan(context) : null,
                  child: const Text('Scan'),
                ),
                ElevatedButton(
                  onPressed: (connection == null) ? null : stop,
                  child: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Text('Board status: ${getDeviceConnectionStateString()}'),
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
                        DataWidget('accX', measures.isNotEmpty ? measures[0] : []),
                        DataWidget('accY', measures.isNotEmpty ? measures[1] : []),
                        DataWidget('accZ', measures.isNotEmpty ? measures[2] : []),
                        DataWidget('gyroX', measures.isNotEmpty ? measures[3] : []),
                        DataWidget('gyroY', measures.isNotEmpty ? measures[4] : []),
                        DataWidget('gyroZ', measures.isNotEmpty ? measures[5] : []),
                        DataWidget('magX', measures.isNotEmpty ? measures[6] : []),
                        DataWidget('magY', measures.isNotEmpty ? measures[7] : []),
                        DataWidget('magZ', measures.isNotEmpty ? measures[8] : []),
                        DataWidget('temp', measures.isNotEmpty ? measures[9] : []),
                        DataWidget('hum', measures.isNotEmpty ? measures[10] : []),
                      ]
                    : [
                        DataLengthWidget('accX', measures.isNotEmpty ? measures[0] : []),
                        DataLengthWidget('accY', measures.isNotEmpty ? measures[1] : []),
                        DataLengthWidget('accZ', measures.isNotEmpty ? measures[2] : []),
                        DataLengthWidget('gyroX', measures.isNotEmpty ? measures[3] : []),
                        DataLengthWidget('gyroY', measures.isNotEmpty ? measures[4] : []),
                        DataLengthWidget('gyroZ', measures.isNotEmpty ? measures[5] : []),
                        DataLengthWidget('magX', measures.isNotEmpty ? measures[6] : []),
                        DataLengthWidget('magY', measures.isNotEmpty ? measures[7] : []),
                        DataLengthWidget('magZ', measures.isNotEmpty ? measures[8] : []),
                        DataLengthWidget('temp', measures.isNotEmpty ? measures[9] : []),
                        DataLengthWidget('hum', measures.isNotEmpty ? measures[10] : []),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

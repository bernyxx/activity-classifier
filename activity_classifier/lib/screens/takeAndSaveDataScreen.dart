import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:activity_classifier/firebase_options.dart';
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
  bool toStop = false;
  bool isFirebaseInitialized = false;

  final flutterReactiveBle = FlutterReactiveBle();
  late DiscoveredDevice nano;
  late Stream<ConnectionStateUpdate> currentConnectionStream;
  StreamSubscription<ConnectionStateUpdate>? connection;

  // 2 BLE services
  final Uuid environmentalSensingService = Uuid.parse("181A");
  final Uuid accelerometerService = Uuid.parse("1101");

  // list of BLE characteristics

  final Uuid temperatureCharacteristic = Uuid.parse("2A6E");
  final Uuid humidityCharacteristic = Uuid.parse("2A6F");

  final Uuid accXCharacteristic = Uuid.parse("2101");
  final Uuid accYCharacteristic = Uuid.parse("2102");
  final Uuid accZCharacteristic = Uuid.parse("2103");

  final Uuid gyroXCharacteristic = Uuid.parse("2201");
  final Uuid gyroYCharacteristic = Uuid.parse("2202");
  final Uuid gyroZCharacteristic = Uuid.parse("2203");

  final Uuid magXCharacteristic = Uuid.parse("2301");
  final Uuid magYCharacteristic = Uuid.parse("2302");
  final Uuid magZCharacteristic = Uuid.parse("2303");

  // list of measures
  List<List<int>> misurazioni = [];

  // cast the list of bytes to int32
  int toSignedInt(List<int> bytes) {
    Int8List numbyte = Int8List.fromList(bytes);

    return numbyte.buffer.asInt32List()[0];
  }

  // scan to search nano suino
  void scan() async {
    toStop = false;
    PermissionStatus permission = await LocationPermissions().requestPermissions();

    late StreamSubscription<DiscoveredDevice> scanStream;

    if (permission == PermissionStatus.granted) {
      scanStream = flutterReactiveBle.scanForDevices(
        withServices: [],
      ).listen((device) async {
        print(device.name);
        if (device.name == "Nano Suino") {
          print("found device!");
          nano = device;
          scanStream.cancel();
          await connectAndGetData();
        }
      }, onError: (err) => print(err));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanning for BLE Peripherals require location permissions!'),
        ),
      );
    }
  }

  // disconnect nano suino
  Future<void> stop() async {
    if (connection == null) {
      return;
    }

    print("stop");
    toStop = true;
    await connection!.cancel();
    connection = null;
    await writeDataToCsv();
  }

  // connect to nano suino and get the data
  Future<void> connectAndGetData() async {
    // connect to the device Nano Suino
    currentConnectionStream = flutterReactiveBle.connectToAdvertisingDevice(id: nano.id, prescanDuration: const Duration(seconds: 1), withServices: []);

    // listen for connection status changes
    connection = currentConnectionStream.listen((event) {
      // print the changes
      print(event);
    });

    // list of characteristics
    final qTemperatureCharacteristic = QualifiedCharacteristic(deviceId: nano.id, serviceId: environmentalSensingService, characteristicId: temperatureCharacteristic);
    final qHumidityCharacteristic = QualifiedCharacteristic(deviceId: nano.id, serviceId: environmentalSensingService, characteristicId: humidityCharacteristic);

    final qAccXCharacteristic = QualifiedCharacteristic(deviceId: nano.id, serviceId: accelerometerService, characteristicId: accXCharacteristic);
    final qAccYCharacteristic = QualifiedCharacteristic(deviceId: nano.id, serviceId: accelerometerService, characteristicId: accYCharacteristic);
    final qAccZCharacteristic = QualifiedCharacteristic(deviceId: nano.id, serviceId: accelerometerService, characteristicId: accZCharacteristic);

    final qGyroXCharacteristic = QualifiedCharacteristic(deviceId: nano.id, serviceId: accelerometerService, characteristicId: gyroXCharacteristic);
    final qGyroYCharacteristic = QualifiedCharacteristic(deviceId: nano.id, serviceId: accelerometerService, characteristicId: gyroYCharacteristic);
    final qGyroZCharacteristic = QualifiedCharacteristic(deviceId: nano.id, serviceId: accelerometerService, characteristicId: gyroZCharacteristic);

    final qMagXCharacteristic = QualifiedCharacteristic(deviceId: nano.id, serviceId: accelerometerService, characteristicId: magXCharacteristic);
    final qMagYCharacteristic = QualifiedCharacteristic(deviceId: nano.id, serviceId: accelerometerService, characteristicId: magYCharacteristic);
    final qMagZCharacteristic = QualifiedCharacteristic(deviceId: nano.id, serviceId: accelerometerService, characteristicId: magZCharacteristic);

    // continue to get data until toStop becomes true
    while (toStop == false) {
      int temp = toSignedInt(await flutterReactiveBle.readCharacteristic(qTemperatureCharacteristic));
      int hum = toSignedInt(await flutterReactiveBle.readCharacteristic(qHumidityCharacteristic));
      int accX = toSignedInt(await flutterReactiveBle.readCharacteristic(qAccXCharacteristic));
      int accY = toSignedInt(await flutterReactiveBle.readCharacteristic(qAccYCharacteristic));
      int accZ = toSignedInt(await flutterReactiveBle.readCharacteristic(qAccZCharacteristic));
      int gyroX = toSignedInt(await flutterReactiveBle.readCharacteristic(qGyroXCharacteristic));
      int gyroY = toSignedInt(await flutterReactiveBle.readCharacteristic(qGyroYCharacteristic));
      int gyroZ = toSignedInt(await flutterReactiveBle.readCharacteristic(qGyroZCharacteristic));
      int magX = toSignedInt(await flutterReactiveBle.readCharacteristic(qMagXCharacteristic));
      int magY = toSignedInt(await flutterReactiveBle.readCharacteristic(qMagYCharacteristic));
      int magZ = toSignedInt(await flutterReactiveBle.readCharacteristic(qMagZCharacteristic));

      // list of the measures
      List<int> mis = [accX, accY, accZ, gyroX, gyroY, gyroZ, magX, magY, magZ, temp, hum];
      print(mis);

      // add the measure to the list and notify the framework that the object changed
      setState(() {
        misurazioni.add(mis);
      });
    }
  }

  Future<File> getFile() async {
    Directory? dir = await getExternalStorageDirectory();
    print(dir!.path);
    return File('${dir.path}/data.csv');
  }

  Future<void> writeDataToCsv() async {
    File file = await getFile();

    String toFile = 'xa,ya,za,xg,yg,zg,xm,ym,zm,temp,hum\n';

    for (var mis in misurazioni) {
      String newLine = '';

      for (int i = 0; i < mis.length; i++) {
        if (i != mis.length - 1) {
          newLine += '${mis[i]},';
        } else {
          newLine += '${mis[i]}\n';
        }
      }

      toFile += newLine;
    }
    file.writeAsString(toFile);
    await uploadFile();
  }

  Future<void> uploadFile() async {
    if (!isFirebaseInitialized) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      isFirebaseInitialized = true;
    }

    final storageRef = FirebaseStorage.instance.ref();
    final DateTime dt = DateTime.now();

    final String timestamp = formatDate(dt, [dd, '_', mm, '_', yyyy, '_', HH, '_', nn, '_', ss]);
    print(timestamp);
    final fileRef = storageRef.child('data_$timestamp.csv');

    File file = await getFile();
    try {
      // upload file to Firebase Storage
      await fileRef.putFile(file);
    } on FirebaseException catch (e) {
      print(e);
    }
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
              'CREATE A NEW DATASET',
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
                  onPressed: scan,
                  child: const Text('Scan'),
                ),
                ElevatedButton(
                  onPressed: (connection == null) ? null : stop,
                  child: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            const Text('The incoming data will be displayed below'),
            Expanded(
              child: ListView.builder(
                reverse: false,
                itemCount: misurazioni.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    child: Card(
                      child: ListTile(
                        title: Text('${misurazioni[index]}'),
                        tileColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

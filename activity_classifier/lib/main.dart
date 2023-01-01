import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:location_permissions/location_permissions.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Activity Classifier',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        primaryColor: Colors.black,
        brightness: Brightness.dark,
        dividerColor: Colors.black12,
      ),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool toStop = false;

  final flutterReactiveBle = FlutterReactiveBle();
  late DiscoveredDevice nano;
  late Stream<ConnectionStateUpdate> currentConnectionStream;
  late StreamSubscription<ConnectionStateUpdate> connection;

  final Uuid environmentalSensingService = Uuid.parse("181A");
  final Uuid accelerometerService = Uuid.parse("1101");

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

  List<List<int>> misurazioni = [];

  int toSignedInt(List<int> bytes) {
    Int8List numbyte = Int8List.fromList(bytes);

    return numbyte.buffer.asInt32List()[0];
  }

  Future<void> connectAndGetData() async {
    currentConnectionStream = flutterReactiveBle.connectToAdvertisingDevice(id: nano.id, prescanDuration: const Duration(seconds: 1), withServices: []);

    connection = currentConnectionStream.listen((event) {
      print(event);
    });

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

    for (int i = 0; i < 100; i++) {
      if (toStop) {
        await stop();
        break;
      }

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

      List<int> mis = [accX, accY, accZ, gyroX, gyroY, gyroZ, magX, magY, magZ, temp, hum];
      print(mis);

      setState(() {
        misurazioni.add(mis);
      });
    }
  }

  void scan() async {
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
          stop();
        }
      }, onError: (err) => print(err));
    }
  }

  Future<void> stop() async {
    print("stop");
    toStop = true;
    await connection.cancel();
    toStop = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Classifier'),
      ),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: scan,
              child: const Text('Scan'),
            ),
            ElevatedButton(
              onPressed: stop,
              child: const Text('Stop'),
            ),
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

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:location_permissions/location_permissions.dart';

class BLEProvider extends ChangeNotifier {
  final flutterReactiveBle = FlutterReactiveBle();

  late StreamSubscription<DiscoveredDevice>? scanStream;

  StreamSubscription<ConnectionStateUpdate>? connection;

  DeviceConnectionState connectionState = DeviceConnectionState.disconnected;

  List<StreamSubscription<dynamic>> streams = [];

  bool isScanning = false;

  // list of measures
  List<List<int>> measures = [];

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

  // cast the list of bytes to an int32
  int toSignedInt(List<int> bytes) {
    Int8List numbyte = Int8List.fromList(bytes);

    return numbyte.buffer.asInt32List()[0];
  }

  // scan BLE devices
  void scan(BuildContext ctx) async {
    // clear the old data
    measures.clear();

    List<DiscoveredDevice> foundDevices = [];
    var navigator = Navigator.of(ctx);
    var messenger = ScaffoldMessenger.of(ctx);

    PermissionStatus permission = await LocationPermissions().requestPermissions();

    if (permission == PermissionStatus.granted) {
      isScanning = true;
      notifyListeners();

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
                    // print('added ${device.name}');
                  });
                }
                // ignore: avoid_print
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
                              onPressed: () => selectDevice(context, foundDevices[index]),
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
                      isScanning = false;
                      setState(() {
                        // isScanning = false;
                        connection = null;
                      });
                      notifyListeners();
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

  // function called when a discovered device is selected from the list during scanning
  void selectDevice(BuildContext ctx, DiscoveredDevice device) async {
    // print("selected device!");
    Navigator.of(ctx).pop();
    scanStream!.cancel();
    await connectAndGetData(device);
  }

  // disconnect the board
  Future<void> stop() async {
    // print("disconnecting board");

    // stop receiving data for all characteristics
    for (StreamSubscription stream in streams) {
      await stream.cancel();
    }

    // disconnect the board
    await connection!.cancel();

    // make connection null to update UI elements
    connection = null;

    notifyListeners();
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
        // print(event);
        connectionState = event.connectionState;
        notifyListeners();
      },
    );

    // better to make isScanning false here because between there is an interval between the time when the device is found and the time
    // when the app is connected to the nano

    // setState(() {
    //   isScanning = false;
    // });

    isScanning = false;
    notifyListeners();

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
        measures[i].add(value);
        notifyListeners();
      }));
    }
  }

  String getDeviceConnectionStateString(DeviceConnectionState connectionState) {
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
}

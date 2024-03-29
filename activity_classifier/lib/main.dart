import 'package:activity_classifier/providers/ble_provider.dart';
import 'package:activity_classifier/screens/take_and_save_data_screen.dart';
import 'package:activity_classifier/screens/classification_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(
    ChangeNotifierProvider(
      create: (context) => BLEProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // set only portrait ortientation
    SystemChrome.setPreferredOrientations(
      [
        DeviceOrientation.portraitUp,
      ],
    );
    FlutterNativeSplash.remove();
    return MaterialApp(
      title: 'Activity Classifier',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        primaryColor: Colors.black,
        brightness: Brightness.dark,
        dividerColor: Colors.black12,
        // set roboto as the app default font family
        fontFamily: 'Roboto',
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
  // index of the screen
  int _bottomNavigationBarIndex = 0;

  // function to update the index of the screen to show, connected to the bottom bar screen selection
  void handleBottomBarTap(int index) {
    setState(() {
      _bottomNavigationBarIndex = index;
    });
  }

  // get the correct screen based on the index
  Widget getBody(int index) {
    if (index == 0) {
      return const TakeAndSaveDataScreen();
    } else {
      return const ClassificationScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Classifier'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavigationBarIndex,
        onTap: (value) => handleBottomBarTap(value),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dataset),
            label: 'New Data',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_),
            label: 'Classify',
          ),
        ],
      ),
      body: getBody(_bottomNavigationBarIndex),
    );
  }
}

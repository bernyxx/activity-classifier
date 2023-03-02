import 'package:activity_classifier/providers/BLEProvider.dart';
import 'package:activity_classifier/screens/classificationScreen.dart';
import 'package:activity_classifier/screens/takeAndSaveDataScreen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
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
  int _bottomNavigationBarIndex = 0;

  void handleBottomBarTap(int index) {
    setState(() {
      _bottomNavigationBarIndex = index;
    });
  }

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

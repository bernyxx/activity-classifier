import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:activity_classifier/screens/takeAndSaveDataScreen.dart';
import 'package:flutter/material.dart';
import 'package:location_permissions/location_permissions.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:date_format/date_format.dart';

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
  int _bottomNavigationBarIndex = 0;

  void handleBottomBarTap(int index) {
    setState(() {
      _bottomNavigationBarIndex = index;
    });
  }

  Widget getBody(int index) {
    if (index == 0) {
      return TakeAndSaveDataScreen();
    } else {
      return Center(
        child: Text('Index $_bottomNavigationBarIndex'),
      );
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

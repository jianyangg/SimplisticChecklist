import 'package:flutter/material.dart';
import 'package:simplistic_checklist/pages/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simplistic Checklist',
      theme: ThemeData(
        useMaterial3: true,
        dialogBackgroundColor: Colors.white,
      ),
      home: const HomePage(),
    );
  }
}

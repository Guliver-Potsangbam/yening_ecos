import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int data;

  @override
  void initState() {
    print("INIT STATE CALLED");
    data = 0;
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    print("HI I AM DISPOSED");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          data++;
          print(data);
          setState(() {});
        },
        child: Icon(Icons.camera),
      ),
      appBar: AppBar(title: Text("Setting Page"), elevation: 1),
      body: Center(
        child: Text(
          data.toString(),
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

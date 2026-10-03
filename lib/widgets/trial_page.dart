import 'package:flutter/material.dart';

class MyTest extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.abc),
      ),
      appBar: AppBar(title: Text("Hello"), elevation: 1),
      body: Center(
        child: Text(
          "hello",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

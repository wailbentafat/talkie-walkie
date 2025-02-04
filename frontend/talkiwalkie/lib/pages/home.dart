import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:talkiwalkie/provider/soundprovider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    final webSocketProvider = Provider.of<WebSocketProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Home'),
      ),
      body: Center(
        child: GestureDetector(
          onLongPress: () {
            print("Recording started...");
            webSocketProvider.startRecording();
          },
          onLongPressUp: () {
            print("Recording stopped.");
            webSocketProvider.stopRecording();
          },
          child: const Icon(
            Icons.mic,
            size: 200,
            color: Colors.deepPurpleAccent,
          ),
        ),
      ),
    );
  }
}
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
    final wsProvider = Provider.of<WebSocketProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Home'),
      ),
      body: Center(
        child: GestureDetector(
          onLongPress: () {
            wsProvider.startRecording(); 
          },
          onLongPressUp: () {
            wsProvider.stopRecording(); 
          },
          child: Icon(
            Icons.mic,
            size: 200,
            color: wsProvider.isRecording ? Colors.red : Colors.deepPurpleAccent,
          ),
        ),
      ),
    );
  }
}

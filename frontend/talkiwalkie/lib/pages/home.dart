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
        title: const Text('Talkie Walkie'),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: wsProvider.isConnected ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Press and hold to talk',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),
            GestureDetector(
              onLongPress: () {
                wsProvider.startRecording(); 
              },
              onLongPressUp: () {
                wsProvider.stopRecording(); 
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: wsProvider.isRecording 
                      ? Colors.red.withOpacity(0.8) 
                      : Colors.deepPurple.withOpacity(0.2),
                  boxShadow: wsProvider.isRecording
                      ? [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 30, spreadRadius: 10)]
                      : [],
                ),
                child: Icon(
                  Icons.mic,
                  size: 100,
                  color: wsProvider.isRecording ? Colors.white : Colors.deepPurpleAccent,
                ),
              ),
            ),
            SizedBox(height: 40),
            Text(
              wsProvider.isRecording 
                  ? 'Speaking...' 
                  : wsProvider.isConnected 
                      ? 'Ready' 
                      : 'Disconnected - Check server',
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w500,
                color: wsProvider.isRecording 
                    ? Colors.red 
                    : wsProvider.isConnected 
                        ? Colors.green 
                        : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
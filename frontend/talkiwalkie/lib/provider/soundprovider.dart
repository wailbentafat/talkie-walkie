import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class WebSocketProvider with ChangeNotifier {
  late IOWebSocketChannel _channel;
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _audioFilePath; 

  WebSocketProvider() {
    connect();
  }

  void connect() {
    _channel = IOWebSocketChannel.connect('ws://192.168.1.163:8080/ws');
    _channel.stream.listen((message) {
      if (message is List<int>) {
        _playAudio(Uint8List.fromList(message));
      }
    });
  }

  Future<void> startRecording() async {
    if (await _recorder.hasPermission()) {
      _isRecording = true;
      notifyListeners();

     
      Directory dir = await getApplicationDocumentsDirectory();
      _audioFilePath = "${dir.path}/recorded_audio.wav";

    
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,  
          sampleRate: 16000,
          numChannels: 1,
        ),
          path: _audioFilePath!,
      );
    }
  }

  Future<void> stopRecording() async {
    await _recorder.stop();
    _isRecording = false;
    notifyListeners();

    if (_audioFilePath != null) {
      print("Recording saved: $_audioFilePath");
      sendAudioToServer(_audioFilePath!);
    }
  }

  void sendAudioToServer(String filePath) async {
    File file = File(filePath);
    if (await file.exists()) {
      List<int> audioBytes = await file.readAsBytes();
      _channel.sink.add(audioBytes);
      print("Audio sent to WebSocket: ${audioBytes.length} bytes");
    } else {
      print("File does not exist!");
    }
  }

  Future<void> _playAudio(Uint8List data) async {
    try {
      await _player.setAudioSource(AudioSource.uri(
        Uri.dataFromBytes(data, mimeType: 'audio/wav'),
      ));
      await _player.play();
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  bool get isRecording => _isRecording;

  @override
  void dispose() {
    _channel.sink.close();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }
}

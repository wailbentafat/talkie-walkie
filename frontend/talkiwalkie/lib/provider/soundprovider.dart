import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

// class WebSocketProvider with ChangeNotifier {
//   late IOWebSocketChannel _channel;
//   final AudioPlayer _player = AudioPlayer();
//   final AudioRecorder _recorder = AudioRecorder();

//   bool _isRecording = false;
//   String? _audioFilePath; 

//   WebSocketProvider() {
//     connect();
//   }

//   void connect() {
//     _channel = IOWebSocketChannel.connect('ws://192.168.1.163:8080/ws');
//     _channel.stream.listen((message) {
//       if (message is List<int>) {
//         _playAudio(Uint8List.fromList(message));
//       }
//     });
//   }

//   Future<void> startRecording() async {
//     if (await _recorder.hasPermission()) {
//       _isRecording = true;
//       notifyListeners();

     
//       Directory dir = await getApplicationDocumentsDirectory();
//       _audioFilePath = "${dir.path}/recorded_audio.wav";

    
//       await _recorder.start(
//         const RecordConfig(
//           encoder: AudioEncoder.wav,  
//           sampleRate: 16000,
//           numChannels: 1,
//         ),
//           path: _audioFilePath!,
//       );
//     }
//   }

//   Future<void> stopRecording() async {
//     await _recorder.stop();
//     _isRecording = false;
//     notifyListeners();

//     if (_audioFilePath != null) {
//       print("Recording saved: $_audioFilePath");
//       sendAudioToServer(_audioFilePath!);
//     }
//   }

//   void sendAudioToServer(String filePath) async {
//     File file = File(filePath);
//     if (await file.exists()) {
//       List<int> audioBytes = await file.readAsBytes();
//       _channel.sink.add(audioBytes);
//       print("Audio sent to WebSocket: ${audioBytes.length} bytes");
//     } else {
//       print("File does not exist!");
//     }
//   }

//   Future<void> _playAudio(Uint8List data) async {
//     try {
//       await _player.setAudioSource(AudioSource.uri(
//         Uri.dataFromBytes(data, mimeType: 'audio/wav'),
//       ));
//       await _player.play();
//     } catch (e) {
//       print('Error playing audio: $e');
//     }
//   }

//   bool get isRecording => _isRecording;

//   @override
//   void dispose() {
//     _channel.sink.close();
//     _player.dispose();
//     _recorder.dispose();
//     super.dispose();
//   }
// }


class WebSocketProvider with ChangeNotifier {
  late IOWebSocketChannel _channel;
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isConnected = false;

  WebSocketProvider() {
    connect();
  }

  void connect() {
    _channel = IOWebSocketChannel.connect('ws://192.168.1.163:8080/ws');
    _isConnected = true;

    _channel.stream.listen((message) {
      print("📥 Received raw audio chunk: ${message.length} bytes");
      if (message is List<int>) {
        _playAudio(Uint8List.fromList(message));
      } else {
        print("❌ Unexpected data type: ${message.runtimeType}");
      }
    }, onError: (error) {
      print("❌ WebSocket error: $error");
      _isConnected = false;
    });
  }

 Future<void> startRecording() async {
  if (await _recorder.hasPermission()) {
    _isRecording = true;
    notifyListeners();

    print("🎙️ Started recording...");

    Stream<Uint8List> audioStream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits, // Send raw PCM for real-time streaming
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    audioStream.listen((data) {  // ✅ Now `.listen()` works!
      if (_isConnected) {
        _channel.sink.add(data); // Send chunks live to WebSocket
        print("📤 Sent audio chunk: ${data.length} bytes");
      }
    });
  }
}

  Future<void> stopRecording() async {
    await _recorder.stop();
    _isRecording = false;
    notifyListeners();
    print("⏹️ Recording stopped.");
  }

  Future<void> _playAudio(Uint8List pcmData) async {
    try {
      print("🔊 Received PCM data, converting to WAV...");
      Uint8List wavData = _convertPCMToWav(pcmData);

      Directory tempDir = await getTemporaryDirectory();
      File tempFile = File('${tempDir.path}/received_audio.wav');
      await tempFile.writeAsBytes(wavData);

      print("🎶 Saved received audio to: ${tempFile.path}");

      await _player.setFilePath(tempFile.path);
      await _player.play();
      print("🔊 Playing received audio...");
    } catch (e) {
      print('❌ Error playing audio: $e');
    }
  }

  Uint8List _convertPCMToWav(Uint8List pcmData) {
    int sampleRate = 16000;
    int channels = 1;
    int byteRate = sampleRate * channels * 2;

    ByteData header = ByteData(44);
    header.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    header.setUint32(4, 36 + pcmData.length, Endian.little);
    header.setUint32(8, 0x57415645, Endian.big); // "WAVE"
    header.setUint32(12, 0x666d7420, Endian.big); // "fmt "
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, channels * 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint32(36, 0x64617461, Endian.big); // "data"
    header.setUint32(40, pcmData.length, Endian.little);

    return Uint8List.fromList(header.buffer.asUint8List() + pcmData);
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

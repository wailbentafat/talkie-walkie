import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

class WebSocketProvider with ChangeNotifier {
  late IOWebSocketChannel _channel;
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  Stream<Uint8List>? _audioStream;

  bool _isRecording = false;

  WebSocketProvider() {
    connect();
  }

 
  void connect() {
    _channel = IOWebSocketChannel.connect('ws://192.168.1.163:8080/ws');
    _channel.stream.handleError((onError) {
      print('Error: $onError');
    });
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

      _audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _audioStream?.listen((audioData) {
        _channel.sink.add(audioData); 
      });
    }
  }


  Future<void> stopRecording() async {
    await _recorder.stop();
    _isRecording = false;
    _audioStream = null;
    notifyListeners();
  }

 
  Uint8List convertPCMToWAV(Uint8List pcmData, {int sampleRate = 16000, int numChannels = 1, int bitsPerSample = 16}) {
    int byteRate = (sampleRate * numChannels * bitsPerSample) ~/ 8;
    int dataSize = pcmData.length;
    int chunkSize = 36 + dataSize;

    //lazam wav header hna 44 byte
    var header = ByteData(44);
    header.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    header.setUint32(4, chunkSize, Endian.little); // Chunk size
    header.setUint32(8, 0x57415645, Endian.big); // "WAVE"
    header.setUint32(12, 0x666d7420, Endian.big); // "fmt "
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    header.setUint16(20, 1, Endian.little); // Audio format (PCM = 1)
    header.setUint16(22, numChannels, Endian.little); // Number of channels
    header.setUint32(24, sampleRate, Endian.little); // Sample rate
    header.setUint32(28, byteRate, Endian.little); // Byte rate
    header.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little); // Block align
    header.setUint16(34, bitsPerSample, Endian.little); // Bits per sample
    header.setUint32(36, 0x64617461, Endian.big); // "data"
    header.setUint32(40, dataSize, Endian.little); // Data size

//ls9 wav m3a pcm 
    return Uint8List.fromList(header.buffer.asUint8List() + pcmData);
  }

  
  Future<void> _playAudio(Uint8List data) async {
    try {
      Uint8List wavData = convertPCMToWAV(data);

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.dataFromBytes(
            wavData,
            mimeType: 'audio/wav',
          ),
        ),
      );

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

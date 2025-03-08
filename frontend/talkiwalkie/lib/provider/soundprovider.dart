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
  bool _isConnected = false;
  
 
  Directory? _tempDir;
  int _chunkCounter = 0;
  bool _isPlaying = false;

  WebSocketProvider() {
    _initTempDir();
    connect();
  }

  Future<void> _initTempDir() async {
    _tempDir = await getTemporaryDirectory();
 
    Directory audioDir = Directory('${_tempDir!.path}/audio_chunks');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    _tempDir = audioDir;
    print("📁 Audio directory created: ${_tempDir!.path}");
  }

  void connect() {
    _channel = IOWebSocketChannel.connect('ws://192.168.1.163:8080/ws');
    _isConnected = true;

    _channel.stream.listen((message) {
      if (message is List<int>) {
        print("📥 Received audio chunk: ${message.length} bytes");
        _handleIncomingAudio(Uint8List.fromList(message));
      } else {
        print("❌ Unexpected data type: ${message.runtimeType}");
      }
    }, onError: (error) {
      print("❌ WebSocket error: $error");
      _isConnected = false;
      notifyListeners();
      
    
      Future.delayed(Duration(seconds: 3), () {
        if (!_isConnected) connect();
      });
    });
  }

  Future<void> startRecording() async {
    if (await _recorder.hasPermission()) {
      _isRecording = true;
      notifyListeners();

      print("🎙️ Started recording...");

      Stream<Uint8List> audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      audioStream.listen((data) {
        if (_isConnected) {
          _channel.sink.add(data); 
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

 
  Future<void> _handleIncomingAudio(Uint8List pcmData) async {
    if (_tempDir == null) await _initTempDir();
    
    try {
      // Convert PCM to WAV
      Uint8List wavData = _convertPCMToWav(pcmData);
      
   
      String chunkPath = '${_tempDir!.path}/chunk_${_chunkCounter++}.wav';
      File chunkFile = File(chunkPath);
      await chunkFile.writeAsBytes(wavData);
      
      print("💾 Saved chunk to: $chunkPath");
      
    
      await _playAudioChunk(chunkFile.path);
      
   
      _cleanupOldChunks();
      
    } catch (e) {
      print('❌ Error handling incoming audio: $e');
    }
  }
  
  // Play an audio chunk immediately
  Future<void> _playAudioChunk(String filePath) async {
    try {
      // If player is already playing, prepare the next chunk
      if (_player.playing) {
        // Queue the next audio file
        await _player.setAudioSource(AudioSource.file(filePath));
      } else {
        // Start playing if not already playing
        await _player.setFilePath(filePath);
        await _player.play();
        _isPlaying = true;
        
        // Listen for when playback completes
        _player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            // Delete the played file
            File(filePath).delete().catchError((e) => print("Error deleting file: $e"));
          }
        });
      }
      
      print("🔊 Playing chunk: $filePath");
    } catch (e) {
      print('❌ Error playing audio chunk: $e');
    }
  }
  
  // Clean up old audio chunks to prevent storage issues
  void _cleanupOldChunks() async {
    try {
      if (_tempDir == null) return;
      
      List<FileSystemEntity> files = _tempDir!.listSync();
      
     
      if (files.length > 10) {
     
        files.sort((a, b) => 
          File(a.path).statSync().modified.compareTo(File(b.path).statSync().modified));
        
     
        for (int i = 0; i < files.length - 10; i++) {
          await File(files[i].path).delete();
          print("🗑️ Deleted old chunk: ${files[i].path}");
        }
      }
    } catch (e) {
      print("❌ Error cleaning up chunks: $e");
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
  bool get isConnected => _isConnected;

  @override
  void dispose() {
    _channel.sink.close();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }
}
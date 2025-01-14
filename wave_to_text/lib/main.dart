// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter/material.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:record/record.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         // This is the theme of your application.
//         //
//         // TRY THIS: Try running your application with "flutter run". You'll see
//         // the application has a purple toolbar. Then, without quitting the app,
//         // try changing the seedColor in the colorScheme below to Colors.green
//         // and then invoke "hot reload" (save your changes or press the "hot
//         // reload" button in a Flutter-supported IDE, or press "r" if you used
//         // the command line to start the app).
//         //
//         // Notice that the counter didn't reset back to zero; the application
//         // state is not lost during the reload. To reset the state, use hot
//         // restart instead.
//         //
//         // This works for code too, not just values: Most code changes can be
//         // tested with just a hot reload.
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         useMaterial3: true,
//       ),
//       home: const MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   final AudioRecorder _record = AudioRecorder();
//   final _audioPlayer = AudioPlayer();
//   String? _filePath;

//   @override
//   void dispose() {
//     _record.dispose();
//     _audioPlayer.dispose();
//     super.dispose();
//   }

//   Future<String> _getFilePath() async {
//     final directory = await getApplicationDocumentsDirectory();
//     return '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
//   }

//   Future<void> _startRecording() async {
//     try {
//       if (await _record.hasPermission()) {
//         final filePath = await _getFilePath();
//         setState(() => _filePath = filePath);

//         await _record.start(RecordConfig(), path: filePath);
//         print('Recording started at $filePath');
//       } else {
//         print('Permission not granted');
//       }
//     } catch (e) {
//       print('Error starting recording: $e');
//     }
//   }

//   Future<void> _stopRecording() async {
//     if (await _record.isRecording()) {
//       await _record.stop();
//       print('Recording stopped. File saved at $_filePath');
//     }
//   }

//   Future<void> _playRecording() async {
//     if (_filePath != null) {
//       try {
//         await _audioPlayer.play(DeviceFileSource(_filePath!));
//       } catch (e) {
//         print('Error playing recording: $e');
//       }
//     } else {
//       print('No recording to play');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Audio Recorder')),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             GestureDetector(
//               onTapDown: (_) => _startRecording(),
//               onTapUp: (_) => _stopRecording(),
//               onTapCancel: _stopRecording,
//               child: Container(
//                 width: 100,
//                 height: 100,
//                 decoration: BoxDecoration(
//                   color: Colors.red,
//                   shape: BoxShape.circle,
//                 ),
//                 child: Center(
//                   child: Icon(Icons.mic, color: Colors.white, size: 50),
//                 ),
//               ),
//             ),
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _playRecording,
//               child: Text('Play Recording'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: VoskFlutterDemo(),
    );
  }
}

class VoskFlutterDemo extends StatefulWidget {
  const VoskFlutterDemo({Key? key}) : super(key: key);

  @override
  State<VoskFlutterDemo> createState() => _VoskFlutterDemoState();
}

class _VoskFlutterDemoState extends State<VoskFlutterDemo> {
  static const _textStyle = TextStyle(fontSize: 30, color: Colors.black);
  static const _modelName = 'vosk-model-small-en-us-0.15';
  static const _sampleRate = 16000;

  final _vosk = VoskFlutterPlugin.instance();
  final _modelLoader = ModelLoader();
  final _record = AudioRecorder();

  String? _fileRecognitionResult;
  String? _error;
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  bool _recognitionStarted = false;
  String? _filePath;

  @override
  void initState() {
    super.initState();

    _modelLoader
        .loadModelsList()
        .then((modelsList) =>
            modelsList.firstWhere((model) => model.name == _modelName))
        .then((modelDescription) =>
            _modelLoader.loadFromNetwork(modelDescription.url)) // load model
        .then(
            (modelPath) => _vosk.createModel(modelPath)) // create model object
        .then((model) => setState(() => _model = model))
        .then((_) => _vosk.createRecognizer(
            model: _model!, sampleRate: _sampleRate)) // create recognizer
        .then((value) => _recognizer = value)
        .then((recognizer) {
      if (Platform.isAndroid) {
        _vosk
            .initSpeechService(_recognizer!) // init speech service
            .then((speechService) =>
                setState(() => _speechService = speechService))
            .catchError((e) => setState(() => _error = e.toString()));
      }
    }).catchError((e) {
      setState(() => _error = e.toString());
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
          body: Center(child: Text("Error: $_error", style: _textStyle)));
    } else if (_model == null) {
      return const Scaffold(
          body: Center(child: Text("Loading model...", style: _textStyle)));
    } else if (Platform.isAndroid && _speechService == null) {
      return const Scaffold(
        body: Center(
          child: Text("Initializing speech service...", style: _textStyle),
        ),
      );
    } else {
      return Platform.isAndroid ? _androidExample() : _commonExample();
    }
  }

  Widget _androidExample() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
                onPressed: () async {
                  if (_recognitionStarted) {
                    await _speechService!.stop();
                  } else {
                    await _speechService!.start();
                  }
                  setState(() => _recognitionStarted = !_recognitionStarted);
                },
                child: Text(_recognitionStarted
                    ? "Stop recognition"
                    : "Start recognition")),
            StreamBuilder(
                stream: _speechService!.onPartial(),
                builder: (context, snapshot) => Text(
                    "Partial result: ${snapshot.data.toString()}",
                    style: _textStyle)),
            StreamBuilder(
                stream: _speechService!.onResult(),
                builder: (context, snapshot) => Text(
                    "Result: ${snapshot.data.toString()}",
                    style: _textStyle)),
          ],
        ),
      ),
    );
  }

  Widget _commonExample() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
                onPressed: () async {
                  if (_recognitionStarted) {
                    await _stopRecording();
                  } else {
                    await _startRecording();
                  }
                  setState(() => _recognitionStarted = !_recognitionStarted);
                },
                child: Text(
                    _recognitionStarted ? "Stop recording" : "Record audio")),
            Text("Final recognition result: $_fileRecognitionResult",
                style: _textStyle),
          ],
        ),
      ),
    );
  }

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<void> _startRecording() async {
    try {
      if (await _record.hasPermission()) {
        final filePath = await _getFilePath();
        setState(() => _filePath = filePath);

        await _record.start(RecordConfig(), path: filePath);
        print('Recording started at $filePath');
      } else {
        print('Permission not granted');
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final filePath = await _record.stop();
      if (filePath != null) {
        final bytes = File(filePath).readAsBytesSync();
        _recognizer!.acceptWaveformBytes(bytes);
        _fileRecognitionResult = await _recognizer!.getFinalResult();
      }
    } catch (e) {
      _error = e.toString() +
          '\n\n Make sure fmedia(https://stsaz.github.io/fmedia/)'
              ' is installed on Linux';
    }
  }
}

// main.dart
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Connect to the Node.js WebSocket server
  final _channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8080'));
  Map<String, dynamic>? _widgetData;

  @override
  void initState() {
    super.initState();
    // Listen for incoming IPC messages
    _channel.stream.listen((message) {
      setState(() {
        _widgetData = jsonDecode(message);
        print("📥 Received from Node: $_widgetData");
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('React -> Flutter Bridge PoC')),
        body: Center(
          child: _buildDynamicWidget(),
        ),
      ),
    );
  }

  // The very beginning of your "Widget Registry"
  Widget _buildDynamicWidget() {
    if (_widgetData == null) {
      return const Text('Waiting for Node.js commands...');
    }
    
    // Imperative to Declarative mapping
    if (_widgetData!['op'] == 'create' && _widgetData!['type'] == 'container') {
       final props = _widgetData!['props'];
       return Container(
         width: (props['width'] as int).toDouble(),
         height: (props['height'] as int).toDouble(),
         color: props['color'] == 'blue' ? Colors.blue : Colors.grey,
         child: Center(
           child: Text(
             props['text'] ?? '', 
             style: const TextStyle(color: Colors.white, fontSize: 18)
            ),
         ),
       );
    }
    
    return const Text('Unknown widget type');
  }
  
  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
}
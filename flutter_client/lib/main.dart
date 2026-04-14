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
  final _channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8080'));
  
  // The Complete Widget Registry
  final Map<String, dynamic> _registry = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize the Root Node manually, since Node.js targets "root" directly
    _registry['root'] = {
      'id': 'root',
      'type': 'container',
      'props': {'color': 'white'},
      'children': [],
      'layout': null // Root layout is dictated by the browser window
    };

    _channel.stream.listen((message) {
      setState(() {
        final data = jsonDecode(message);
        
        switch (data['op']) {
          case 'create':
            // Add to registry with an empty children list
            _registry[data['id']] = {
              ...data,
              'children': <String>[],
              'layout': null
            };
            break;
            
          case 'appendChild':
            // Link parent and child in our tree
            final parentId = data['parentId'];
            final childId = data['childId'];
            if (_registry.containsKey(parentId)) {
              if (!_registry[parentId]['children'].contains(childId)) {
                 _registry[parentId]['children'].add(childId);
              }
            }
            break;
            
          case 'removeChild':
            final parentId = data['parentId'];
            final childId = data['childId'];
            if (_registry.containsKey(parentId)) {
              _registry[parentId]['children'].remove(childId);
            }
            break;

          case 'update':
            // Update the React props dynamically
            if (_registry.containsKey(data['id'])) {
              _registry[data['id']]['props'] = data['props'];
            }
            break;

          case 'layout':
            // Apply the Yoga layout coordinates
            if (_registry.containsKey(data['id'])) {
              _registry[data['id']]['layout'] = {
                'x': data['x'],
                'y': data['y'],
                'w': data['w'],
                'h': data['h'],
              };
            }
            break;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Yoga-Driven React Renderer')),
        body: Container(
          color: Colors.grey[200], // Background to see the canvas boundary
          // Start rendering from the root downwards
          child: _buildWidgetTree('root'),
        ),
      ),
    );
  }

  // --- THE RECURSIVE RENDERER (UPDATED) ---
  Widget _buildWidgetTree(String nodeId) {
    final node = _registry[nodeId];
    if (node == null) return const SizedBox.shrink();

    final type = node['type'];
    final props = node['props'] ?? {};
    final childrenIds = List<String>.from(node['children'] ?? []);

    // 1. Recursively build all children
    List<Widget> childrenWidgets = childrenIds.map((childId) {
      final childNode = _registry[childId];
      if (childNode == null) return const SizedBox.shrink();

      final layout = childNode['layout'];
      final isText = childNode['type'] == 'text';

      // If it's not text and has no layout yet, wait for Yoga to calculate it
      if (layout == null && !isText) return const SizedBox.shrink();

      return Positioned(
        // Default to 0,0 if Yoga didn't provide coordinates (like for text)
        left: layout?['x']?.toDouble() ?? 0.0,
        top: layout?['y']?.toDouble() ?? 0.0,
        width: layout?['w']?.toDouble(),   // null width lets text size itself naturally
        height: layout?['h']?.toDouble(),
        child: _buildWidgetTree(childId), 
      );
    }).toList();

    // 2. Render the actual element type
    if (type == 'container' || type == 'root') {
      return Container(
        decoration: BoxDecoration(
          color: _parseColor(props['color']),
          // Adding a red border to the root so you can see where the canvas starts!
          border: type == 'root' 
              ? Border.all(color: Colors.red, width: 2) 
              : Border.all(color: Colors.black12), 
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: childrenWidgets,
        ),
      );
    } 
    
    else if (type == 'text') {
      // Text just renders itself, Yoga handles the container around it
      return Text(
        props['text'] ?? '', 
        style: const TextStyle(fontSize: 18, color: Colors.black87),
      );
    } 
    
    else if (type == 'button') {
      return ElevatedButton(
        onPressed: () {
          debugPrint("👆 Button Clicked! Sending back to Node...");
          _channel.sink.add(jsonEncode({
            "event": "click",
            "targetId": props['id'] ?? nodeId
          }));
        },
        child: Text(props['text'] ?? 'Button'),
      );
    }

    return const SizedBox.shrink();
  }

  // Helper to turn strings into Flutter colors
  Color _parseColor(String? colorStr) {
    switch (colorStr) {
      case 'blue': return Colors.blue;
      case 'red': return Colors.red;
      case 'green': return Colors.green;
      case 'white': return Colors.white;
      default: return Colors.transparent;
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
}
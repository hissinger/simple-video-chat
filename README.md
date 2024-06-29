# Simple Video Chat App

this is a simple video chat application using flutter and WebRTC.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Signaling Server

this app needs a signaling server. refer to the [repo](https://github.com/hissinger/simple-video-chat-server)

and signaling server url should be set in `lib/call_page.dart` file.

```dart
  void _connectSocket() {
    print("connect server");
    const url = ""; // HERE SET SIGNALING SERVER URL
    socket = IO.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket!.connect();
```

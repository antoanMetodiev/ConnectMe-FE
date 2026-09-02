import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/chat_controller.dart';

/// Full-screen view-once photo. Downloading here is what "opens" it — by
/// the time this screen is showing, the repository has already flipped the
/// message to viewed and deleted the file, so there's no way back in.
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.messageId,
    required this.storagePath,
  });

  final String messageId;
  final String storagePath;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late final Future<Uint8List> _photo;

  @override
  void initState() {
    super.initState();
    _photo = ref
        .read(chatRepositoryProvider)
        .openPhoto(
          messageId: widget.messageId,
          storagePath: widget.storagePath,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Uint8List>(
        future: _photo,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          return InteractiveViewer(
            child: Center(
              child: Image.memory(snapshot.data!, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}

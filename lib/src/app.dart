import 'package:flutter/material.dart';
import 'homepage.dart';

class YouTubeDownloader extends StatefulWidget {
  const YouTubeDownloader({super.key});

  @override
  State<YouTubeDownloader> createState() => _YouTubeDownloaderState();
}

class _YouTubeDownloaderState extends State<YouTubeDownloader> {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'YouTube Downloader',
        home: Scaffold(
          appBar: AppBar(
            title: const Text('YouTube Downloader'),
          ),
          body: const Homepage(),
        ),
      );
}

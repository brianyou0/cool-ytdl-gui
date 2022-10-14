import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'vidTile.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final _formKey = GlobalKey<FormState>();
  final urlController = TextEditingController();

  String? _directoryPath = '';
  String linkEntryMessage = '';
  String dlMessage = '';
  bool isAudio = false;
  List<String> videoQueue = <String>[];
  List<double> dlPercents = <double>[];

  void _selectFolder() async {
    String? path = await FilePicker.platform.getDirectoryPath();
    setState(() {
      _directoryPath = path ?? _directoryPath;
    });
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  void downloadVids() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    var options = <String>[];
    if (isAudio) {
      options.add('-x');
    }
    if (_directoryPath != null) {
      options.add('-o');
      options.add('$_directoryPath\\%(title)s.%(ext)s');
    }

    if (!File('./yt-dlp.exe').existsSync()) {
      debugPrint('yt-dlp missing, downloading...');
      try {
        Response response = await Dio().get(
          'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe',
          onReceiveProgress: (count, total) {
            if (total != -1) {
              debugPrint('${count / total * 100}%');
            }
          },
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) => status! < 500,
          ),
        );
        File file = File('yt-dlp.exe');
        var raf = file.openSync(mode: FileMode.write);
        raf.writeFromSync(response.data);
        await raf.close();
      } catch (e) {
        debugPrint(e.toString());
      }
    }

    var processes = <Process>[];
    var processPercents = <double>[];
    for (var index = 0; index < videoQueue.length; index++) {
      var process =
          await Process.start('./yt-dlp.exe', options + [videoQueue[index]]);
      process.stdout.transform(utf8.decoder).forEach((out) {
        final percentInd = out.indexOf('% of');
        if (percentInd != -1) {
          setState(() {
            dlPercents[index] =
                double.parse(out.substring(percentInd - 4, percentInd)) / 100.0;
            debugPrint(index.toString() + dlPercents[index].toString());
            dlMessage = dlPercents[index] >= 1
                ? 'Download complete!'
                : 'Downloading video...';
          });
        }
      });
      process.stderr.transform(utf8.decoder).forEach((err) {
        if (err.contains('not a valid URL')) {
          setState(() {
            dlMessage = 'Error: Not a valid URL.';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: 'Enter video or playlist URL',
                suffixIcon: IconButton(
                  onPressed: () => setState(() {
                    if (urlController.text == '') {
                      linkEntryMessage =
                          'Please enter a video or playlist URL.';
                    } else if (videoQueue.contains(urlController.text)) {
                      linkEntryMessage = 'Link already in queue.';
                    } else {
                      videoQueue.add(urlController.text);
                      dlPercents.add(0.0);
                      linkEntryMessage = '';
                    }
                    urlController.clear();
                    debugPrint(videoQueue.toString());
                  }),
                  icon: const Icon(Icons.add),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                linkEntryMessage,
                textAlign: TextAlign.left,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            Expanded(
              child: videoQueue.isNotEmpty
                  ? ListView.builder(
                      itemCount: videoQueue.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            color: Colors.black12,
                          ),
                          child: Row(
                            children: [
                              Text(videoQueue[index].toString()),
                              const Spacer(),
                              SizedBox(
                                width: 300,
                                child: LinearPercentIndicator(
                                  animation: true,
                                  animationDuration: 100,
                                  animateFromLastPercent: true,
                                  lineHeight: 20.0,
                                  percent: dlPercents[index],
                                  center: Text((dlPercents[index] * 100)
                                      .toStringAsFixed(2)),
                                  barRadius: const Radius.circular(15),
                                  progressColor: Colors.green,
                                ),
                              ),
                              IconButton(
                                  onPressed: () => setState(() {
                                        videoQueue.removeAt(index);
                                      }),
                                  icon: const Icon(Icons.close)),
                            ],
                          ),
                        );
                      },
                    )
                  : const Center(),
            ),
            Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey),
                  onPressed: () => _selectFolder(),
                  child: const Text('Select destination folder'),
                ),
                const SizedBox(
                  width: 15,
                ),
                Text(_directoryPath != null ? _directoryPath! : ''),
                const Spacer(),
                IconButton(
                    onPressed: () => {
                          setState(() {
                            _directoryPath = null;
                          })
                        },
                    icon: const Icon(Icons.cancel)),
              ],
            ),
            CheckboxListTile(
              title: const Text("Keep only audio"),
              value: isAudio,
              onChanged: (newValue) {
                setState(() {
                  isAudio = !isAudio;
                });
              },
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: downloadVids,
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Download'),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => videoQueue.clear()),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15.0),
            Text(dlMessage),
          ],
        ),
      ),
    );
  }
}
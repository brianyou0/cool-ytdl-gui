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
  double dlPercent = 0.0;
  bool isAudio = false;
  var videoQueue = [];

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
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      itemBuilder: (context, index) {
                        return Row(
                          children: [
                            Text(videoQueue[index].toString()),
                            const Spacer(),
                            IconButton(
                                onPressed: () => setState(() {
                                      videoQueue.removeAt(index);
                                    }),
                                icon: const Icon(Icons.close))
                          ],
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(36),
              ),
              onPressed: () async {
                if (!_formKey.currentState!.validate()) {
                  return;
                }

                var options = [urlController.text];
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

                var process = await Process.start('./yt-dlp.exe', options);
                process.stdout.transform(utf8.decoder).forEach((out) {
                  final percentInd = out.indexOf('% of');
                  if (percentInd != -1) {
                    setState(() {
                      dlPercent = double.parse(
                              out.substring(percentInd - 4, percentInd)) /
                          100.0;
                      debugPrint(dlPercent.toString());
                      dlMessage = dlPercent >= 1
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
              },
              child: const Text('Submit'),
            ),
            const SizedBox(height: 15.0),
            LinearPercentIndicator(
              animation: true,
              animationDuration: 100,
              animateFromLastPercent: true,
              lineHeight: 20.0,
              percent: dlPercent,
              center: Text((dlPercent * 100).toStringAsFixed(2)),
              barRadius: const Radius.circular(15),
              progressColor: Colors.green,
            ),
            const SizedBox(height: 15.0),
            Text(dlMessage),
          ],
        ),
      ),
    );
  }
}

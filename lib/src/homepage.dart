import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:percent_indicator/percent_indicator.dart';

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
  bool linkError = false;
  List<Map> videoQueue = <Map>[];
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

  void addLink() async {
    if (urlController.text == '') {
      setState(() {
        linkEntryMessage = 'Please enter a video or playlist URL.';
        linkError = true;
      });
    } else if (videoQueue
        .map((v) => v["webpage_url"])
        .contains(urlController.text)) {
      setState(() {
        linkEntryMessage = 'Link already in queue.';
        linkError = true;
      });
    } else {
      setState(() {
        linkEntryMessage = 'Retrieving URL...';
        linkError = false;
      });

      var process = await Process.run(
          './yt-dlp.exe', ['-j', '--skip-download', urlController.text]);

      if (process.stderr.toString().contains('not a valid URL')) {
        setState(() {
          linkEntryMessage = 'Invalid URL.';
          linkError = true;
        });
        return;
      }

      setState(() {
        videoQueue.add(jsonDecode(process.stdout.toString()));
        dlPercents.add(0.0);
        urlController.clear();
        linkEntryMessage = 'URL added.';
        linkError = false;
      });
    }
  }

  void downloadVids() async {
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

    var completeVids = 0;
    setState(() =>
        dlMessage = 'Downloading video${videoQueue.length > 1 ? 's' : ''}...');

    for (var index = 0; index < videoQueue.length; index++) {
      var process = await Process.start(
          './yt-dlp.exe', options + [videoQueue[index]["webpage_url"]]);
      process.stdout.transform(utf8.decoder).forEach((out) {
        final percentInd = out.indexOf('% of');
        if (percentInd != -1) {
          setState(() {
            dlPercents[index] =
                double.parse(out.substring(percentInd - 4, percentInd)) / 100.0;
            debugPrint('${index.toString()} ${dlPercents[index].toString()}');
            if (dlPercents[index] >= 1) {
              completeVids++;
              if (completeVids == videoQueue.length) {
                dlMessage = 'Download complete!';
              }
            }
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
                  onPressed: () => addLink(),
                  icon: const Icon(Icons.add),
                ),
              ),
              onFieldSubmitted: (value) => addLink(),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                linkEntryMessage,
                textAlign: TextAlign.left,
                style: TextStyle(color: linkError ? Colors.red : Colors.black),
              ),
            ),
            Expanded(
              child: videoQueue.isNotEmpty
                  ? ListView.builder(
                      itemCount: videoQueue.length,
                      itemBuilder: (context, index) {
                        return Container(
                          height: 100,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            color: Colors.black12,
                          ),
                          child: Row(
                            children: [
                              Image.network(videoQueue[index]["thumbnail"]),
                              const SizedBox(width: 20),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 5),
                                  Text(
                                    videoQueue[index]["title"],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text('by ${videoQueue[index]['uploader']}'),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Duration: ${Duration(seconds: videoQueue[index]["duration"]).toString().split('.')[0]}',
                                  ),
                                  const SizedBox(height: 5),
                                ],
                              ),
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

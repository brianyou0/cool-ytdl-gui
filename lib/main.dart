import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:percent_indicator/percent_indicator.dart';

void main() => runApp(const YtDlr());

class YtDlr extends StatelessWidget {
  const YtDlr({super.key});

  @override
  Widget build(BuildContext context) {
    const appTitle = 'YouTube Downloader';

    return MaterialApp(
      title: appTitle,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(appTitle),
        ),
        body: const MyCustomForm(),
      ),
    );
  }
}

class MyCustomForm extends StatefulWidget {
  const MyCustomForm({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyCustomFormState createState() => _MyCustomFormState();
}

class _MyCustomFormState extends State<MyCustomForm> {
  final _formKey = GlobalKey<FormState>();
  final urlController = TextEditingController();

  String? _directoryPath = '';
  var dlMessage = '';
  double dlPercent = 0.0;
  bool isAudio = false;

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
            SizedBox(
              height: 75,
              child: TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: urlController,
                decoration: const InputDecoration(
                    hintText: 'Enter video or playlist ID or URL'),
                validator: (value) {
                  return (value == null || value.isEmpty)
                      ? 'ID or URL is required'
                      : null;
                },
              ),
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

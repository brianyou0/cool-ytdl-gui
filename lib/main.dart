import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

void main() => runApp(const YtDlpApp());

class YtDlpApp extends StatelessWidget {
  const YtDlpApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'YouTube Downloader',
      localizationsDelegates: [
        FormBuilderLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: CompleteForm(),
    );
  }
}

class CompleteForm extends StatefulWidget {
  const CompleteForm({Key? key}) : super(key: key);

  @override
  State<CompleteForm> createState() {
    return _CompleteFormState();
  }
}

class _CompleteFormState extends State<CompleteForm> {
  bool autoValidate = true;
  final _formKey = GlobalKey<FormBuilderState>();

  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  String? _directoryPath;

  void _selectFolder() async {
    _resetState();
    try {
      String? path = await FilePicker.platform.getDirectoryPath();
      setState(() {
        _directoryPath = path;
      });
    } on PlatformException catch (e) {
      _logException('Unsupported operation ${e.toString()}');
    } catch (e) {
      _logException(e.toString());
    }
  }

  void _logException(String message) {
    debugPrint(message);
    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _resetState() {
    if (!mounted) {
      return;
    }
    setState(() {
      _directoryPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Downloader')),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              FormBuilder(
                key: _formKey,
                onChanged: () {
                  _formKey.currentState!.save();
                },
                child: Column(
                  children: <Widget>[
                    FormBuilderTextField(
                      name: 'vidID',
                      decoration: const InputDecoration(
                        labelText: 'Video ID',
                        hintText: 'youtube.com/watch?v=(this part)',
                      ),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                      ]),
                    ),
                    FormBuilderCheckbox(
                      name: 'audio_only_switch',
                      initialValue: false,
                      title: const Text('Keep audio only'),
                    ),
                  ],
                ),
              ),
              Row(
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () => _selectFolder(),
                    child: const Text('Select Directory'),
                  ),
                  const SizedBox(width: 10),
                  Builder(
                    builder: (BuildContext context) => _directoryPath != null
                        ? Text(_directoryPath!)
                        : const SizedBox(),
                  )
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.saveAndValidate() ?? false) {
                          var options = [
                            'https://www.youtube.com/watch?v=${_formKey.currentState?.value['vidID']}',
                          ];
                          if (_formKey
                              .currentState?.value['audio_only_switch']) {
                            options.add('-x');
                          }
                          if (_directoryPath != null) {
                            options.add('-o');
                            options.add('$_directoryPath/%(title)s.%(ext)s');
                          }

                          Process.run('./lib/yt-dlp.exe', options)
                              .then((ProcessResult results) {
                            debugPrint(results.stderr);
                            debugPrint(results.stdout);
                          });
                        } else {
                          debugPrint(_formKey.currentState?.value.toString());
                          debugPrint('validation failed');
                        }
                      },
                      child: const Text('Submit'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _formKey.currentState?.reset();
                      },
                      child: Text(
                        'Reset',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

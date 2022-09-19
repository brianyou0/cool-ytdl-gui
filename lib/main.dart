import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
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
  bool _idHasError = false;

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
                      onChanged: (val) {
                        setState(() {
                          _idHasError = !(_formKey.currentState?.fields['vidID']
                                  ?.validate() ??
                              false);
                        });
                      },
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
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.saveAndValidate() ?? false) {
                          var options = [
                            'https://www.youtube.com/watch?v=${_formKey.currentState?.value['vidID']}'
                          ];
                          if (_formKey
                              .currentState?.value['audio_only_switch']) {
                            options.add('-x');
                          }

                          Process.run('./lib/yt-dlp.exe', options)
                              .then((ProcessResult results) {
                            debugPrint(results.stdout);
                          });
                        } else {
                          debugPrint(_formKey.currentState?.value.toString());
                          debugPrint('validation failed');
                        }
                      },
                      child: const Text(
                        'Submit',
                        style: TextStyle(color: Colors.white),
                      ),
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

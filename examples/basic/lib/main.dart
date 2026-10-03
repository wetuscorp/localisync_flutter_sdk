import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:localisync_sdk/localisync_sdk.dart';
import 'configuration.dart';
import 'generated/localisync_messages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Roboto',
    ], await rootBundle.loadString('licenses/Roboto-LICENSE.txt'));
  });
  try {
    runApp(ExampleRoot(client: createLocalisyncClient(exampleConfiguration())));
  } on Object catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                error is FormatException
                    ? error.message.toString()
                    : 'Localisync setup is invalid. Check the example configuration.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExampleRoot extends StatefulWidget {
  const ExampleRoot({super.key, required this.client});
  final LocalisyncClient client;
  @override
  State<ExampleRoot> createState() => _ExampleRootState();
}

class _ExampleRootState extends State<ExampleRoot> {
  @override
  void dispose() {
    unawaited(widget.client.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LocalisyncScope(client: widget.client, child: const TranslationApp());
}

class TranslationApp extends StatelessWidget {
  const TranslationApp({super.key});
  @override
  Widget build(BuildContext context) {
    final client = LocalisyncScope.of(context);
    return MaterialApp(
      title: 'Localisync',
      locale: flutterLocale(client.locale),
      supportedLocales: const [Locale('en'), Locale('tr')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        fontFamily: 'Localisync Sans',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
      ),
      darkTheme: ThemeData(
        fontFamily: 'Localisync Sans',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.dark,
        ),
      ),
      home: const TranslationHome(),
    );
  }
}

class TranslationHome extends StatelessWidget {
  const TranslationHome({super.key});
  @override
  Widget build(BuildContext context) {
    final client = LocalisyncScope.of(context);
    final messages = LocalisyncMessages(client);

    return Scaffold(
      appBar: AppBar(title: Text(messages.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  messages.greeting(name: 'Developer'),
                  key: const Key('greeting'),
                ),
                Text(messages.basket(count: 3)),

                const SizedBox(height: 20),
                const TextField(
                  key: Key('preserved-input'),
                  decoration: InputDecoration(
                    labelText: 'Your draft',
                    helperText: 'Updates preserve this input and navigation.',
                  ),
                ),
                DropdownButton<String>(
                  value: client.locale,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'tr', child: Text('Turkish')),
                  ],
                  onChanged: (locale) {
                    if (locale != null) unawaited(client.setLocale(locale));
                  },
                ),
                StreamBuilder<LocalisyncStatus>(
                  stream: client.changes,
                  initialData: client.status,
                  builder: (context, snapshot) {
                    final status = snapshot.data ?? client.status;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Update: ${status.phase.name}',
                          key: const Key('update-status'),
                        ),
                        if (status.failure != null)
                          Text(status.failure!.message),
                        if (!status.persisted)
                          const Text(
                            'Content is available in memory. Persistent storage is unavailable.',
                          ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed:
                              status.phase == UpdatePhase.checking ||
                                  status.phase == UpdatePhase.downloading
                              ? null
                              : () {
                                  unawaited(client.refresh());
                                },
                          child: const Text('Check for updates'),
                        ),
                        if (client.hasPending)
                          OutlinedButton(
                            onPressed: () {
                              unawaited(client.activatePending());
                            },
                            child: const Text('Activate update'),
                          ),
                      ],
                    );
                  },
                ),
                TextButton(
                  onPressed: () {
                    unawaited(
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Preserved route'),
                            ),
                            body: Center(
                              child: Text(context.translate('title')),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open another screen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

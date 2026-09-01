/// The entrypoint for the **server** environment.
///
/// The [main] method will only be executed on the server during pre-rendering.
/// To run code on the client, check the `main.client.dart` file.
library;

// Server-specific Jaspr import.
import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

// Imports the [App] component.
import 'app.dart';
import 'constants/theme.dart';
import 'constants/wedding_data.dart';

// This file is generated automatically by Jaspr, do not remove or edit.
import 'main.server.options.dart';

void main() {
  // Initializes the server environment with the generated default options.
  Jaspr.initializeApp(
    options: defaultServerOptions,
  );

  // Starts the app.
  //
  // [Document] renders the root document structure (<html>, <head> and <body>)
  // with the provided parameters and components.
  runApp(
    Document(
      base: const String.fromEnvironment('base_href', defaultValue: '/'),
      title: 'Nosso casamento',
      meta: {
        'viewport': 'width=device-width, initial-scale=1',
        'description': 'Site do casamento de $brideName e $groomName',
      },
      head: [
        link(rel: 'icon', type: 'image/svg+xml', href: 'favicon.svg'),
        link(rel: 'alternate icon', href: 'favicon.ico'),
      ],
      styles: themeStyles,
      body: App(),
    ),
  );
}

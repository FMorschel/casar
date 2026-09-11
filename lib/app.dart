import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'pages/album_page.dart';
import 'pages/home_page.dart';
import 'pages/photo_challenges_page.dart';

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return Router(
      routes: [
        Route(path: '/', builder: (context, state) => const HomePage()),
        Route(
          path: '/fotos',
          builder: (context, state) => const PhotoChallengesPage(),
        ),
        Route(path: '/album', builder: (context, state) => const AlbumPage()),
      ],
    );
  }
}

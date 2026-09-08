import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/couple_section.dart';
import '../components/footer.dart';
import '../components/gift_list.dart';
import '../components/hero.dart';
import '../components/navbar.dart';

/// Conteúdo da rota `/` (página principal do site).
class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'app', [
      const Navbar(),
      const Hero(),
      const CoupleSection(),
      const GiftList(),
      const Footer(),
    ]);
  }
}

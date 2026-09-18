/// Central place to edit the wedding content for the mockup.
library;

const brideName = 'Júlia';
const groomName = 'Felipe';
const coupleHashtag = '#JuFe';

/// Wedding date/time used by the countdown and the hero section.
final weddingDate = DateTime(2026, 9, 18, 19, 0);

/// 7h da manhã do dia após [weddingDate]; a galeria de fotos dos desafios
/// fica borrada até essa data (FR-18).
DateTime get photoRevealDate {
  final d = weddingDate.add(const Duration(days: 1));
  return DateTime(d.year, d.month, d.day, 7);
}

const venueName = 'Meridiano 55';

/// Dados do Pix usados pelo QR Code da lista de presentes.
const pixKey = '7f90e389-335b-430e-9d99-6c51c367ec1e';
const pixReceiverName = '$brideName e $groomName';
const pixCity = 'PORTO ALEGRE';

class BioInfo {
  final String name;
  final String emoji;
  final String bio;

  const BioInfo({required this.name, required this.emoji, required this.bio});
}

const brideBio = BioInfo(
  name: brideName,
  emoji: '🧠',
  bio:
      'Estudante de psicologia, leitora voraz e frequentadora assídua da academia e das aulas de spinning. '
      'Canta músicas aleatórias e inventa sons engraçados para tudo — e conheceu o Felipe num jantar '
      'de amigos, comendo hambúrguer.',
);

const groomBio = BioInfo(
  name: groomName,
  emoji: '💻',
  bio:
      'Desenvolvedor, gamer e resolvedor de cubos mágicos nas horas vagas, lê de vez em quando e sabe '
      'muitos fatos aleatórios. Vai à academia com a Júlia e diz que conhecê-la naquele jantar de '
      'hambúrguer foi o melhor commit da vida dele.',
);

class GiftItem {
  final String emoji;
  final String name;
  final String price;

  /// Quem sugeriu a ideia. Vazio para os itens oficiais da lista.
  final String author;

  const GiftItem({
    required this.emoji,
    required this.name,
    required this.price,
    this.author = '',
  });
}

/// Emojis que os convidados podem escolher ao sugerir uma ideia.
const giftEmojiOptions = [
  '💡',
  '🎁',
  '🍕',
  '🍫',
  '🍣',
  '☕',
  '🧉',
  '🍻',
  '🎮',
  '🕹️',
  '🎬',
  '📺',
  '📖',
  '🧩',
  '🎧',
  '🎸',
  '🐈‍⬛',
  '🐶',
  '🌻',
  '💐',
  '🏋️',
  '🚴',
  '🛋️',
  '🛏️',
  '🧦',
  '🧼',
  '🚿',
  '🧳',
  '✈️',
  '🏖️',
  '💸',
  '💍',
  '🥂',
  '🎉',
  '🥳',
  '❤️',
  '🤍',
  '✨',
  '🌙',
  '🔥',
];

/// O catálogo oficial de [GiftItem]s não mora mais aqui: é a aba
/// `lista_presentes` da planilha, buscada em `utils/gift_ideas_api.dart` —
/// única fonte dele, sem cópia local no site.

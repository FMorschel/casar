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

const giftList = [
  GiftItem(emoji: '🐈‍⬛', name: 'Ajuda com sachê da Atena', price: 'R\$ 5'),
  GiftItem(emoji: '🚴', name: 'Aula de spinning da noiva', price: 'R\$ 40'),
  GiftItem(emoji: '🏋️', name: 'Academia do noivo', price: 'R\$ 120'),
  GiftItem(
    emoji: '💐',
    name: 'A noiva jogar o buquê na sua direção',
    price: 'R\$ 300',
  ),
  GiftItem(
    emoji: '🎮',
    name: 'Internet pro noivo jogar com os amiguinhos',
    price: 'R\$ 110',
  ),
  GiftItem(
    emoji: '🧩',
    name: 'Cubo mágico pro noivo se divertir na lua de mel',
    price: 'R\$ 30',
  ),
  GiftItem(
    emoji: '📖',
    name: 'Livro pra noiva levar na lua de mel',
    price: 'R\$ 50',
  ),
  GiftItem(
    emoji: '🧦',
    name: 'Meias pra noiva parar de roubar as do noivo',
    price: 'R\$ 10',
  ),
  GiftItem(
    emoji: '🤍',
    name: 'Poder ir de branco no casamento',
    price: 'R\$ 1.000',
  ),
  GiftItem(emoji: '🎬', name: 'Cinema mensal dos noivos', price: 'R\$ 70'),
  GiftItem(
    emoji: '🥳',
    name: 'Taxa pra despedida de solteiro',
    price: 'R\$ 5.000',
  ),
  GiftItem(
    emoji: '🕯️',
    name: 'Kit incenso pra noiva ficar tranquila',
    price: 'R\$ 20',
  ),
  GiftItem(
    emoji: '🌙',
    name: 'Taxa para jogar de madrugada com o noivo',
    price: 'R\$ 15',
  ),
  GiftItem(emoji: '🎁', name: 'Lembrancinha da lua de mel', price: 'R\$ 25'),
  GiftItem(emoji: '🛏️', name: 'Dormir na casa dos noivos', price: 'R\$ 40'),
  GiftItem(emoji: '☕', name: 'Cafezinho do noivo', price: 'R\$ 20'),
  GiftItem(emoji: '🧉', name: 'Erva-mate da noiva', price: 'R\$ 20'),
  GiftItem(emoji: '🍫', name: '1 mês de chocolate pra noiva', price: 'R\$ 50'),
  GiftItem(emoji: '🕹️', name: 'Jogo novo da Steam pro noivo', price: 'R\$ 60'),
  GiftItem(emoji: '🏢', name: 'Ajuda com o condomínio', price: 'R\$ 80'),
  GiftItem(
    emoji: '📦',
    name: 'Brinquedo pra Atena preferir mais da caixa',
    price: 'R\$ 10',
  ),
  GiftItem(emoji: '🍕', name: 'Pizza de sexta-feira', price: 'R\$ 30'),
  GiftItem(emoji: '📺', name: 'Mensalidade do streaming', price: 'R\$ 15'),
  GiftItem(
    emoji: '🍣',
    name: 'Sushi pra noiva no dia do casamento',
    price: 'R\$ 60',
  ),
  GiftItem(
    emoji: '🍽️',
    name: 'Taxa pro noivo lavar a louça de madrugada',
    price: 'R\$ 200',
  ),
  GiftItem(
    emoji: '🛋️',
    name: 'Taxa pra noiva não querer sair no fim de semana (e o noivo ter paz)',
    price: 'R\$ 200',
  ),
  GiftItem(
    emoji: '👃',
    name: 'Naridrin do noivo',
    price: 'R\$ 15',
  ),
];

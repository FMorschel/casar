/// Sorteio dos desafios de foto de um convidado.
///
/// Espelha `pickChallenges_` do Apps Script (`tools/apps_script/Code.gs`):
/// quando o endpoint está configurado quem sorteia é o servidor, que é o
/// único que sabe o que os outros convidados já pegaram; sem endpoint, o
/// mesmo sorteio roda aqui só com o que este navegador conhece. As duas
/// implementações precisam andar juntas.
library;

import 'dart:math';

import '../constants/photo_challenges.dart';

/// Quantas vezes uma frase prioritária entra no sorteio em relação a uma não
/// prioritária. Não é uma garantia (a garantia é o mínimo de 1 prioritária
/// por sorteio), só o peso maior que elas têm nas vagas restantes.
const _priorityWeight = 3;

/// Sorteia até [count] desafios para um convidado.
///
/// As regras, em ordem:
///
/// 1. nenhuma frase se repete para o mesmo convidado ([pickedByGuest]);
/// 2. todo sorteio traz pelo menos uma frase prioritária, enquanto sobrar
///    alguma prioritária que este convidado ainda não pegou;
/// 3. as vagas restantes saem de qualquer frase, com peso maior para as
///    prioritárias — não é obrigatório sair uma não prioritária;
/// 4. em qualquer vaga, frases que nenhum convidado pegou ainda
///    ([pickedByAnyone]) têm preferência absoluta sobre as que já saíram
///    para alguém — o banco de frases é percorrido inteiro antes de repetir;
/// 5. se não sobrar frase suficiente, devolve menos que [count] (inclusive
///    lista vazia) em vez de repetir — daí em diante o convidado segue só
///    com os desafios que ele mesmo escrever.
List<PhotoChallenge> drawPhotoChallenges({
  required Set<String> pickedByGuest,
  required Set<String> pickedByAnyone,
  int count = challengesPerDraw,
  Random? random,
}) {
  final rng = random ?? Random();
  final available = [
    for (final challenge in allPhotoChallenges)
      if (!pickedByGuest.contains(challenge.text)) challenge,
  ];

  final picked = <PhotoChallenge>[];
  if (count > 0) {
    final priority = [
      for (final challenge in available)
        if (challenge.priority) challenge,
    ];
    if (priority.isNotEmpty) {
      picked.add(_pickOne(priority, pickedByAnyone, rng));
    }
  }

  while (picked.length < count) {
    final candidates = [
      for (final challenge in available)
        if (!picked.contains(challenge)) challenge,
    ];
    if (candidates.isEmpty) break;
    picked.add(_pickOne(candidates, pickedByAnyone, rng));
  }

  return picked;
}

/// Escolhe uma frase de [candidates], preferindo as que ninguém pegou ainda
/// e, dentro disso, dando mais peso às prioritárias.
PhotoChallenge _pickOne(
  List<PhotoChallenge> candidates,
  Set<String> pickedByAnyone,
  Random rng,
) {
  final fresh = [
    for (final challenge in candidates)
      if (!pickedByAnyone.contains(challenge.text)) challenge,
  ];
  final pool = fresh.isNotEmpty ? fresh : candidates;
  final weighted = [
    for (final challenge in pool)
      ...List.filled(challenge.priority ? _priorityWeight : 1, challenge),
  ];
  return weighted[rng.nextInt(weighted.length)];
}

/// Desafios escritos pelo próprio convidado, liberados depois que ele
/// completa os desafios sorteados.
library;

import '../constants/photo_challenges.dart';
import 'text_formatting.dart';

/// Teto de tamanho da frase, igual ao `MAX_CHALLENGE` do Apps Script — o que
/// passar disso seria cortado na planilha e ficaria diferente do que o
/// convidado leu na tela.
const maxCustomChallengeLength = 200;

/// Por que a frase escrita pelo convidado não serve.
enum CustomChallengeError {
  /// Menos de três palavras.
  tooFewWords,

  /// Alguma palavra com menos de duas letras.
  wordTooShort,

  /// Passa de [maxCustomChallengeLength].
  tooLong,

  /// Já existe um desafio com esse texto (sorteável ou do próprio convidado).
  duplicate;

  /// Explicação em português, para mostrar embaixo do campo.
  String get message => switch (this) {
    tooFewWords => 'Escreva pelo menos três palavras.',
    wordTooShort => 'Cada palavra precisa ter pelo menos duas letras.',
    tooLong => 'Essa frase ficou longa demais — encurte um pouco.',
    duplicate => 'Esse desafio já existe. Que tal inventar outro?',
  };
}

/// Deixa a frase no formato que vai ser gravado: sem espaços nas pontas nem
/// espaços repetidos no meio, e com maiúscula no começo e depois de cada
/// ponto — sem precisar pedir isso pro convidado.
String normalizeCustomChallenge(String text) =>
    capitalizeAfterDots(text.trim().replaceAll(RegExp(r'\s+'), ' '));

/// Valida a frase já normalizada por [normalizeCustomChallenge], devolvendo
/// `null` quando ela serve.
///
/// [bank] é o banco de frases buscado da planilha (ver
/// [PhotoChallengesApi.fetchChallengeBank]). [alsoAvoid] são frases que
/// também contam como repetidas além do banco de desafios — na prática, os
/// desafios que este convidado já tem.
CustomChallengeError? validateCustomChallenge(
  String text, {
  required List<PhotoChallenge> bank,
  Iterable<String> alsoAvoid = const [],
}) {
  if (text.length > maxCustomChallengeLength) {
    return CustomChallengeError.tooLong;
  }

  final words = text.split(' ');
  if (words.length < 3) return CustomChallengeError.tooFewWords;
  for (final word in words) {
    if (_countLetters(word) < 2) return CustomChallengeError.wordTooShort;
  }

  // Comparação em maiúsculas: o que muda só na caixa é o mesmo desafio.
  final upper = text.toUpperCase();
  for (final existing in bank) {
    if (existing.text.toUpperCase() == upper) {
      return CustomChallengeError.duplicate;
    }
  }
  for (final existing in alsoAvoid) {
    if (existing.toUpperCase() == upper) return CustomChallengeError.duplicate;
  }

  return null;
}

/// Quantas letras (ignorando números e pontuação) [word] tem.
int _countLetters(String word) =>
    RegExp('[a-zA-ZÀ-ÖØ-öø-ÿ]').allMatches(word).length;

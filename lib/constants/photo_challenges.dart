/// Desafios de foto sorteados para os convidados e a galeria compartilhada
/// com o que eles enviarem.
library;

import '../utils/text_formatting.dart';

/// Um desafio de foto que pode ser sorteado para um convidado.
class PhotoChallenge {
  /// O texto do desafio, mostrado para o convidado.
  final String text;

  /// Desafios prioritários entram no sorteio com mais peso (implementação
  /// do sorteio fica por conta de quem consumir esta lista).
  final bool priority;

  /// Frase escrita pelo próprio convidado, não sorteada do banco de frases.
  ///
  /// Só existe depois que ele completa os desafios sorteados — a partir daí
  /// ele pode continuar mandando fotos com desafios que inventar.
  final bool isCustom;

  const PhotoChallenge({
    required this.text,
    required this.priority,
    this.isCustom = false,
  });

  /// Um desafio escrito pelo próprio convidado.
  PhotoChallenge.custom(String text)
    : text = capitalizeAfterDots(text),
      priority = false,
      isCustom = true;

  // Igualdade por texto: os desafios voltam da planilha/`localStorage` como
  // instâncias novas a cada leitura, então comparar por identidade faria a
  // mesma frase parecer dois desafios diferentes.
  @override
  bool operator ==(Object other) =>
      other is PhotoChallenge && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Quantos desafios saem em cada sorteio.
const challengesPerDraw = 3;

/// Procura um desafio pelo seu [text] em [bank].
///
/// O sorteio salvo (planilha/`localStorage`) só guarda o texto do desafio,
/// não a flag [PhotoChallenge.priority] — esta função é o caminho de volta
/// de texto para o desafio completo. [bank] é o banco de frases buscado da
/// planilha (aba `banco_desafios`, ver [PhotoChallengesApi.fetchChallengeBank]) —
/// única fonte dele, não há mais uma cópia local no site.
PhotoChallenge? findPhotoChallengeByText(
  List<PhotoChallenge> bank,
  String text,
) {
  for (final challenge in bank) {
    if (challenge.text == text) return challenge;
  }
  return null;
}

/// Devolve o desafio de [text] em [bank], tratando o que não está no banco de
/// frases como um desafio escrito pelo próprio convidado.
///
/// Depois dos sorteados, o convidado pode mandar fotos com frases que ele
/// mesmo escreveu — elas voltam da planilha misturadas com as sorteadas e só
/// dá para diferenciá-las assim, por não estarem no banco.
PhotoChallenge resolvePhotoChallenge(List<PhotoChallenge> bank, String text) =>
    findPhotoChallengeByText(bank, text) ?? PhotoChallenge.custom(text);

/// Um desafio atribuído a um convidado, junto com o progresso local da
/// captura (FR-13).
class AssignedChallenge {
  /// O desafio sorteado.
  final PhotoChallenge challenge;

  /// A foto confirmada pelo convidado, como `data:image/...;base64,...`.
  ///
  /// `null` enquanto o convidado ainda não tirou/confirmou a foto.
  final String? confirmedPhotoDataUrl;

  const AssignedChallenge({
    required this.challenge,
    this.confirmedPhotoDataUrl,
  });

  /// Se a foto deste desafio já foi confirmada pelo convidado.
  bool get isConfirmed => confirmedPhotoDataUrl != null;

  /// Devolve uma cópia com [confirmedPhotoDataUrl] substituído.
  AssignedChallenge copyWith({String? confirmedPhotoDataUrl}) {
    return AssignedChallenge(
      challenge: challenge,
      confirmedPhotoDataUrl:
          confirmedPhotoDataUrl ?? this.confirmedPhotoDataUrl,
    );
  }
}

/// Uma foto da galeria compartilhada entre os convidados (FR-16, FR-17).
class GalleryPhoto {
  /// O texto do desafio que gerou esta foto.
  final String challengeText;

  /// Nome do convidado que enviou a foto.
  final String authorName;

  /// URL da foto já salva (não é mais o `data:` local).
  final String photoUrl;

  /// Quando a foto foi tirada.
  final DateTime takenAt;

  const GalleryPhoto({
    required this.challengeText,
    required this.authorName,
    required this.photoUrl,
    required this.takenAt,
  });
}

/// Resultado de um sorteio (FR-8), incluindo fotos já confirmadas antes para
/// algum desses desafios — permite marcar um desafio como feito assim que os
/// desafios chegam do servidor, sem depender do `localStorage` deste
/// aparelho (ex.: convidado abrindo em outro aparelho).
class DrawnChallenges {
  /// Id do convidado na planilha (aba `convidados`) — é o que o site guarda
  /// para se identificar daqui pra frente e para corrigir o nome depois
  /// (ver [PhotoChallengesApi.renameGuest]).
  final String guestId;

  /// Nome do convidado como está na planilha agora. Pode não ser o nome que
  /// este navegador tem salvo, se o convidado corrigiu o nome em outro
  /// aparelho — quem chama deve atualizar o nome salvo com este.
  final String guestName;

  /// Os desafios sorteados (ou recuperados) para o convidado.
  final List<PhotoChallenge> challenges;

  /// Texto do desafio -> URL da foto já confirmada para ele, se houver.
  final Map<String, String> confirmedPhotos;

  const DrawnChallenges({
    required this.guestId,
    required this.guestName,
    required this.challenges,
    required this.confirmedPhotos,
  });
}

/// Configuração dos serviços externos usados pelo site.
library;

/// URL `/exec` do Apps Script que guarda as ideias de presente na planilha.
///
/// Enquanto estiver vazia, o site funciona normalmente: as ideias sugeridas
/// ficam só no navegador de quem escreveu, como antes.
///
/// Veja tools/apps_script/README.md para gerar essa URL.
const giftIdeasEndpoint =
    'https://script.google.com/macros/s/AKfycbzr7mukSRP3OBlBinA2St214QWCZpm1HFkSqbRavLX5wI6ZCAIJFAyuCVW3SSXTPyLA/exec';

/// URL `/exec` do Apps Script que atribui desafios e guarda as fotos.
/// Vazia = modo local (FR-9, FR-15), como [giftIdeasEndpoint].
const photoChallengesEndpoint = giftIdeasEndpoint;

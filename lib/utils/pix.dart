/// Geração do payload "BR Code" (Pix copia e cola) no formato EMV®QRCPS-MPM.
library;

/// Monta um campo EMV: id + tamanho (2 dígitos) + valor.
String _field(String id, String value) {
  final length = value.length.toString().padLeft(2, '0');
  return '$id$length$value';
}

/// CRC-16/CCITT-FALSE, exigido pelo campo 63 do BR Code.
String _crc16(String payload) {
  var crc = 0xFFFF;
  for (final byte in payload.codeUnits) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// Remove acentos, símbolos e espaços extras — os bancos só aceitam
/// caracteres ASCII simples nos campos de texto do BR Code.
String _ascii(String value, int maxLength) {
  const accents = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'ê': 'e',
    'è': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    buffer.write(accents[char] ?? char);
  }
  final cleaned = buffer
      .toString()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.length > maxLength
      ? cleaned.substring(0, maxLength).trim()
      : cleaned;
}

/// Converte um preço como `R$ 1.000` ou `12,50` no formato do Pix (`1000.00`).
/// Retorna `null` quando não há um número reconhecível — nesse caso o QR é
/// gerado sem valor e o pagador digita quanto quiser.
String? parsePixAmount(String price) {
  final match = RegExp(r'\d[\d.,]*').firstMatch(price);
  if (match == null) return null;
  var digits = match.group(0)!;
  // Formato brasileiro: ponto separa milhar, vírgula separa centavos.
  digits = digits.replaceAll('.', '').replaceAll(',', '.');
  final value = double.tryParse(digits);
  if (value == null || value <= 0) return null;
  return value.toStringAsFixed(2);
}

/// Monta o código Pix copia e cola para uma chave aleatória.
///
/// [amount] já deve vir no formato `0.00` (veja [parsePixAmount]); quando nulo
/// o valor fica em aberto. [message] vira a descrição mostrada pelo app do
/// banco.
String buildPixPayload({
  required String key,
  required String merchantName,
  required String merchantCity,
  String? amount,
  String message = '',
}) {
  final gui = _field('00', 'br.gov.bcb.pix');
  final account = _field('01', key);
  // O campo 26 inteiro cabe em 99 caracteres (o tamanho tem só 2 digitos), e
  // a descrição é o que sobra depois da GUI, da chave e do próprio cabeçalho
  // do subcampo 02.
  final descriptionLimit = 99 - gui.length - account.length - 4;
  final description = descriptionLimit <= 0
      ? ''
      : _ascii(message, descriptionLimit < 40 ? descriptionLimit : 40);
  final merchantAccount =
      gui + account + (description.isEmpty ? '' : _field('02', description));

  final payload = StringBuffer()
    ..write(_field('00', '01'))
    ..write(_field('01', '11')) // QR estático (reutilizável)
    ..write(_field('26', merchantAccount))
    ..write(_field('52', '0000'))
    ..write(_field('53', '986')) // BRL
    ..write(amount == null ? '' : _field('54', amount))
    ..write(_field('58', 'BR'))
    ..write(_field('59', _ascii(merchantName, 25)))
    ..write(_field('60', _ascii(merchantCity, 15)))
    ..write(_field('62', _field('05', '***')))
    ..write('6304');

  return '$payload${_crc16(payload.toString())}';
}

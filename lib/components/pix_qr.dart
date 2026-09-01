import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:qr/qr.dart';

/// Desenha o BR Code como um único `<path>` SVG: cada módulo escuro vira um
/// pequeno quadrado, o que mantém o QR nítido em qualquer tamanho e sem
/// depender de imagem externa.
class PixQr extends StatelessComponent {
  const PixQr({required this.data, this.size = 176, super.key});

  final String data;
  final int size;

  @override
  Component build(BuildContext context) {
    final code = QrCode(payload: QrPayload.fromString(data));
    final image = QrImage(code);
    final count = code.moduleCount;
    // Uma borda de 2 módulos (quiet zone) ajuda a leitura pelos apps.
    const quiet = 2;
    final extent = count + quiet * 2;

    final qrPath = StringBuffer();
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (image.isDark(row, col)) {
          qrPath.write('M${col + quiet} ${row + quiet}h1v1h-1z');
        }
      }
    }

    return svg(
      viewBox: '0 0 $extent $extent',
      width: size.px,
      height: size.px,
      classes: 'pix-qr',
      attributes: {'role': 'img', 'aria-label': 'QR Code do Pix'},
      [
        rect(
          width: '$extent',
          height: '$extent',
          fill: const Color('#ffffff'),
          [],
        ),
        path(d: qrPath.toString(), fill: const Color('#000000'), []),
      ],
    );
  }
}

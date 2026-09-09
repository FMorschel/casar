# casar

A new Jaspr project

## Running the project

Run your project using `jaspr serve`.

The development server will be available on `http://localhost:8080`.

## Building the project

Build your project using `jaspr build`.

The output will be located inside the `build/jaspr/` directory.

## Modo prévia (testar `/fotos` antes do casamento)

O site publicado roda em release, então os atalhos de `kDebugMode` somem.
Para os noivos testarem a página de desafios antes da data existe o **modo
prévia**, ligado de duas formas:

- digitando `Felipe+Júlia` (ou `Júlia+Felipe`) no lugar do nome, no portão
  que abre o `/fotos` — sem acento e em qualquer caixa também vale;
- abrindo `/fotos?previa=felipe+julia`, para quando este navegador já tem um
  nome salvo e o portão nem chega a aparecer.

Ligado, ele fica salvo no navegador e mostra o painel 🛠 no canto superior
esquerdo, com:

- **Trocar de nome** — esquece o nome salvo e volta ao portão (o sorteio
  continua guardado, então redigitar o mesmo nome traz tudo de volta);
- **Apagar nome e sorteio** — o mesmo, mas apagando também o sorteio deste
  navegador. Não mexe na planilha: um nome que já sorteou lá volta com o
  mesmo sorteio, então use um nome novo para um sorteio novo;
- **Revelar o álbum agora** / **Borrar o álbum de novo** — mostra o álbum
  sem esperar `photoRevealDate`, e desfaz;
- **Sair do modo prévia**.

Em `jaspr serve` o painel aparece sozinho (`kDebugMode`), sem senha.

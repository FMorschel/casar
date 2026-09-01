# Ideias de presente na planilha do Google

O site é estático (GitHub Pages), então ele não tem para onde gravar nada. Quem
guarda as ideias sugeridas pelos convidados é um Google Apps Script publicado
como *Web App*, escrevendo numa planilha do Google.

Planilha usada:
<https://docs.google.com/spreadsheets/d/1k3tCCPiyT5ZT9Bf11rGKgDognTCDmyjYxFj8R7P9XeU/edit>

## Publicando o script (uma vez só)

1. Abra a planilha → **Extensões → Apps Script**.
2. Apague o conteúdo de `Código.gs` e cole o de [`Code.gs`](Code.gs).
3. Salve (o nome do projeto pode ser `casar-ideias`).
4. **Implantar → Nova implantação → Tipo: App da Web**, com:
   - *Executar como*: **Eu**
   - *Quem pode acessar*: **Qualquer pessoa**
5. Autorize quando o Google pedir (vai aparecer um aviso de "app não
   verificado" — é o seu próprio script; siga em *Avançado → Acessar*).
6. Copie a **URL do app da Web** (termina em `/exec`).
7. Cole essa URL em `giftIdeasEndpoint`, em
   [`lib/constants/config.dart`](../../lib/constants/config.dart), e publique o
   site.

A aba `ideias` é criada sozinha no primeiro envio, com as colunas
`timestamp | emoji | nome | valor | autor`.

## Depois

- Para apagar uma ideia, basta deletar a linha na planilha — o site reflete na
  próxima visita.
- Se mudar o `Code.gs`, use **Implantar → Gerenciar implantações → editar →
  Nova versão** para manter a *mesma* URL. Uma "Nova implantação" gera uma URL
  diferente e o site pararia de achar a planilha.
- Enquanto `giftIdeasEndpoint` estiver vazia, o site funciona igual, só que as
  ideias ficam apenas no navegador de quem escreveu.

## O que este endpoint é (e não é)

A URL aceita escrita de qualquer pessoa, sem login e sem aprovação — foi o
combinado. Os limites que existem são de tamanho de campo e um teto de 500
ideias (a mais antiga sai). Se alguém escrever bobagem, a correção é apagar a
linha na planilha.

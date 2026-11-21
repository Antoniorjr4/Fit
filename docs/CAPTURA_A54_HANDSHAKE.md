# Capturar o handshake da Fit3 no Galaxy A54 (sem root)

O objetivo deste procedimento é **gravar o A54 conversando com a Fit3** para entender o aperto de mão cifrado. O A54 é só o professor: ele já sabe o segredo porque provisionou a pulseira. Gravamos ele fazendo isso, estudamos a gravação e ensinamos o iPhone a repetir. Nada roda no A54 no fim; o app continua sendo o do iPhone.

O Android tem um gravador de Bluetooth embutido, o **btsnoop**, que anota cada byte trocado com a pulseira num arquivo. Não precisa de root. O truque — que faltou na tentativa anterior, quando o log veio vazio — é a **ordem**: ligar o registro, reiniciar o rádio, só então reproduzir o tráfego.

## Antes de começar

- O A54 e um cabo USB.
- O PC com as **platform-tools** da Android (o `adb`, que você já usou no projeto).
- O [Wireshark](https://www.wireshark.org/download.html) instalado no PC (grátis), para conferir e inspecionar a captura.
- Python 3 no PC, para rodar o analisador `ble_lab/snoop_handshake.py`.

> **Privacidade:** a captura vai conter o conteúdo real das suas notificações (mensagens, quem ligou). Trate o arquivo como pessoal — não publique no GitHub nem mande para grupo. Para mim, você pode mandar; se preferir, faça um teste só com notificações falsas ("teste 1", "teste 2").

## Passo 1 — Opções de Desenvolvedor e Depuração USB

1. **Ajustes > Sobre o telefone > Informações do software.**
2. Toque **7 vezes** em "Número da versão" até aparecer "Você agora é um desenvolvedor".
3. Volte, entre em **Ajustes > Opções de desenvolvedor.**
4. Ligue **Depuração USB.**

## Passo 2 — Ligar o registro de HCI Bluetooth

1. Ainda em Opções de desenvolvedor, procure **"Registro de HCI Bluetooth"** (Bluetooth HCI snoop log).
2. Ligue. Se aparecer um menu com opções (Desativado / Filtrado / Ativado), escolha **Ativado** — a opção "Filtrado" apaga o conteúdo dos pacotes, que é justamente o que a gente precisa.

## Passo 3 — Reiniciar o rádio (o passo que faltou antes)

O registro só começa a gravar num ciclo novo do Bluetooth. Por isso:

1. **Desligue o Bluetooth** do A54.
2. Espere 5 segundos.
3. **Ligue o Bluetooth** de novo.

Sem isso, o arquivo volta vazio — foi o que aconteceu na tentativa registrada no dossiê.

## Passo 4 — Reproduzir o aperto de mão

Agora force a pulseira a conversar, por 1 a 2 minutos (quanto mais curto, mais fácil de ler depois):

1. Abra o **Galaxy Wearable** e deixe a Fit3 conectar e sincronizar.
2. Peça para alguém te mandar uma mensagem no **WhatsApp** (ou mande de outro número) para disparar uma notificação na pulseira.
3. Faça uma **ligação** rápida para o seu número, para a pulseira vibrar o aviso de chamada.
4. Toque uma **música** no celular e use o controle no pulso, se tiver.

Cada uma dessas ações passa por um canal diferente, mas todas atravessam o mesmo aperto de mão cifrado. Anote mais ou menos o horário de cada uma — ajuda a achar no arquivo.

## Passo 5 — Extrair o arquivo

Como o aparelho não tem root, a gente não consegue pegar o arquivo direto (a pasta é protegida — foi o "Permission denied" do dossiê). O caminho que funciona é o **relatório de bug**, que embala o btsnoop junto. No PC, com o A54 conectado:

```
adb bugreport fit3_captura.zip
```

Isso gera um `fit3_captura.zip`. Dentro dele, o arquivo que interessa fica em:

```
FS/data/misc/bluetooth/logs/btsnoop_hci.log
```

(pode haver também um `btsnoop_hci.log.last`, de um ciclo anterior — pegue os dois). Extraia esse arquivo para uma pasta.

## Passo 6 — Conferir que NÃO veio vazio

Antes de comemorar, confirme que gravou de verdade:

- O `btsnoop_hci.log` deve ter **pelo menos algumas centenas de KB**. Se vier com poucos KB ou zero, não gravou — volte ao Passo 2 e 3.
- Abra no **Wireshark**. Na barra de filtro, digite `btatt` e Enter. Devem aparecer dezenas ou centenas de linhas. Se aparecer vazio, não gravou o conteúdo (provável opção "Filtrado").

## Passo 7 — Rodar o analisador

Na pasta do projeto, no PC:

```
python ble_lab/snoop_handshake.py caminho/para/btsnoop_hci.log > handshake.txt
```

Ele varre a captura, separa cada escrita e notificação, marca a direção (quem mandou, fone ou pulseira) e mostra os bytes. Nos canais proprietários (1A1A, FD69) é onde o aperto de mão aparece: o A54 escreve uma resposta, a pulseira responde.

## Passo 8 — Me mandar

Anexe aqui o `handshake.txt` (a saída do analisador). Se ele vier pobre, me mande também o `btsnoop_hci.log` em si, ou a captura aberta e exportada do Wireshark. Com isso a gente olha o aperto de mão e decide se dá para reconstruir a chave.

## Se travar

- **Só existe "Filtrado", não "Ativado":** algumas versões da One UI restringem. Sem a opção completa, o conteúdo vem apagado e o caminho fica bloqueado por aqui. Me avise que a gente pensa numa alternativa.
- **O zip não tem o btsnoop:** rode `adb bugreport` logo depois de reproduzir, sem desligar o Bluetooth no meio.
- **`adb` não acha o aparelho:** confirme a Depuração USB e aceite o aviso "Permitir depuração USB?" que aparece na tela do A54.

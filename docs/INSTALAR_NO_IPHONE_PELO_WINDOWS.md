# Instalar o FitΛ no iPhone usando o Windows

Não exige Mac nem a assinatura paga do Apple Developer Program. O aplicativo é compilado nos servidores macOS do GitHub e assinado no seu computador com o seu próprio ID Apple.

## 1. Baixar o aplicativo

1. Abra **Actions** no repositório e escolha a execução mais recente de **FitLambda - iPhone device build** com sucesso.
2. Em **Artifacts**, baixe `FitLambda-iPhone-unsigned-<número>` e extraia o ZIP. Dentro dele está `FitLambda-<versão>-unsigned.ipa`.

O arquivo não tem assinatura. Ele não abre sozinho no iPhone; o passo seguinte assina e instala.

## 2. Assinar e instalar

1. Instale o iTunes e o iCloud **baixados do site da Apple** (as versões da Microsoft Store não funcionam com essas ferramentas).
2. Instale o [Sideloadly](https://sideloadly.io/).
3. Conecte o iPhone por cabo, desbloqueie e toque em **Confiar** neste computador.
4. No Sideloadly, arraste o `.ipa`, informe o seu ID Apple e clique em **Start**. A senha é enviada à Apple para gerar o certificado pessoal. Se preferir, use um ID Apple criado só para isso.
5. No iPhone: **Ajustes > Geral > VPN e Gerenciamento de Dispositivo**, toque no seu ID Apple e em **Confiar**.
6. No iOS 16 ou posterior, ative **Ajustes > Privacidade e Segurança > Modo de Desenvolvedor** e reinicie quando solicitado.

Limites de um ID Apple gratuito: o app vale por 7 dias e precisa ser reinstalado pelo mesmo processo (os dados são mantidos), com até três apps instalados dessa forma por aparelho. Com a assinatura paga, o mesmo `.ipa` passa a valer por um ano e pode ir para o TestFlight (veja `TESTFLIGHT.md`).

## 3. Primeiro teste com a Fit3

1. Abra o FitΛ, escolha o idioma e vá em **Pulseira > Procurar minha Fit3**.
2. Aceite o pedido de Bluetooth do iOS.
3. Se a Fit3 não aparecer, desligue por um instante o Bluetooth do celular Android em que ela está pareada: conectada a ele, a pulseira pode não se anunciar. Isso não desfaz o pareamento.
4. Toque na pulseira. O app conecta, lê os serviços e mostra sinal, bateria (se a pulseira expuser) e as informações do rádio.
5. Para batimentos, inicie uma medição ou um exercício na pulseira e observe o cartão **Batimentos da Fit3**.
6. Afaste a pulseira e volte: o estado deve passar por **Reconectando** e retornar a **Conectada** sozinho.
7. Em **Registro técnico**, toque em **Compartilhar registro** e guarde o arquivo. Ele lista serviços, características e eventos, e é a evidência do Gate 1 do dossiê técnico.

Por padrão o app só lê. A opção **Escutar canais proprietários** apenas assina notificações. A opção **Sessão Samsung (experimental)** é a única que envia dados à pulseira: responde à saudação dela e pede o nível da bateria. Se a Fit3 aparecer na lista de Bluetooth dos Ajustes do iPhone e a conexão falhar, use **Esquecer Este Dispositivo**, reinicie o iPhone e procure de novo.

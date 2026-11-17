# FitΛ no iPhone via TestFlight

A primeira beta usa o FitΛ 0.4.0 com dados e estados de demonstração. O alvo de instalação é iPhone com iOS 17.0 ou superior. O identificador atual é `com.annalabs.fitlambda`. Confirme que ele pode ser registrado na equipe Apple antes de configurar a assinatura.

O fluxo **FitLambda - iPhone device build** verifica se a configuração Release gera um arquivo para iPhone físico com Xcode 26. Essa etapa gera um arquivo sem assinatura em um executor temporário e serve para validar a compilação.

## Conta e instalação

1. Confirme a associação ativa no [Apple Developer Program](https://developer.apple.com/account/) e o acesso ao [App Store Connect](https://appstoreconnect.apple.com/). A associação é necessária para distribuir no TestFlight.
2. Registre o identificador do app e crie o registro iOS no App Store Connect.
3. Use a equipe Apple para assinar a compilação de distribuição. No GitHub Actions, configure os materiais de assinatura e a autenticação de envio como segredos, seguindo o [guia de assinatura do GitHub](https://docs.github.com/pt/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications). Guarde senhas, certificados privados e chaves de API fora do repositório e do chat.
4. Envie a compilação assinada ao App Store Connect e aguarde o processamento. Associe o build a um grupo de testers internos e abra o convite no [TestFlight](https://developer.apple.com/testflight/) no iPhone.

No primeiro teste físico, confirme a seleção de idioma, a troca pelo Perfil, contraste dos dois temas, texto ampliado e acesso às ações de recuperação pelo menu de cenários.

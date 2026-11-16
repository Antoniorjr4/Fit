# FitΛ

Interface nativa em desenvolvimento para aproximar a Galaxy Fit3 da experiência do iPhone.

O design usa grafite, verde-lima e um modo claro em branco suave. A primeira etapa contém as telas **Hoje, Evolução, Pulseira e Perfil**, com dados fictícios e interações de demonstração. Compatibilidade BLE e funcionalidades da pulseira serão validadas separadamente.

## Estado do projeto

- Prévia web navegável e identidade visual aprovadas.
- Base SwiftUI para iOS 17 ou posterior.
- Compilação e abertura em simulador de iPhone pelo GitHub Actions, sem Mac local.
- Bluetooth, sincronização com a Fit3, HealthKit e envio de mostradores ainda não implementados.
- O artefato de simulador não é uma IPA instalável no iPhone.

## Compilar e ver o app sem Mac local

O workflow **FitLambda - native UI validation** valida alterações em `ios/`, no script de build e no próprio workflow quando um pull request é aberto ou atualizado contra `main`. Também aceita execução manual quando estiver disponível na branch padrão.

Após a execução, abra o run em **Actions** e baixe `FitLambda-native-ui-<número>`:

- `build.log`: resultado da compilação.
- `launch.log`: resultado da abertura no simulador.
- `FitLambda-native-dark.png`: captura nativa da interface.
- `FitLambda-simulator.zip`: aplicativo para simulador.
- `environment.txt`: Xcode, XcodeGen e commit utilizados.

A primeira execução em macOS é a confirmação de compilação. Conferência de YAML ou da prévia web não substitui esse resultado.

O job usa runner padrão `macos-15`, limite de 25 minutos e retenção de artefatos por 7 dias. Não usa certificados ou segredos de assinatura e não publica no TestFlight ou na App Store.

## Prévia web no Windows/Linux

Abra `dist/index.html` no navegador, ou execute:

```bash
python -m http.server 8080 --directory dist
```

Depois abra `http://localhost:8080`.

## Em um Mac com Xcode e XcodeGen

```bash
bash scripts/build-ui-macos.sh
```

Para gerar o projeto e abri-lo manualmente:

```bash
cd ios
xcodegen generate
open FitLambda.xcodeproj
```

## Estrutura

| Pasta | Finalidade |
| --- | --- |
| `ios/FitLambda` | Aplicativo SwiftUI e dados de demonstração |
| `ios/project.yml` | Projeto XcodeGen |
| `dist` | Prévia visual HTML/CSS/JavaScript |
| `scripts` | Compilação e captura em macOS |
| `ble_lab` | Sonda BLE inicial, preservada da etapa anterior |
| `docs` | Design, limites, plano e proposta de integração |

## Trabalho em paralelo

Esta frente cuida da interface e da compilação nativa. A frente de integração cuida do protocolo, pareamento, autenticação, leitura, escrita e sincronização com a Fit3.

Leia [o contrato proposto de integração](docs/FRONTEND_BACKEND_HANDOFF.md) e [o design aprovado](docs/VISUAL_DESIGN.md). As views devem receber dados prontos para exibição; não devem implementar mensagens GATT ou autenticação Samsung.

Para instalar em iPhone por TestFlight, ainda será necessário configurar a assinatura e a conta Apple Developer Program. A integração com a Fit3 permanece uma etapa independente.

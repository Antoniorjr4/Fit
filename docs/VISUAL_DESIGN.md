# FitΛ — direção visual 01

Data: 15/11/2026. Versão de design: 0.2.0.

## Intenção

Uma experiência de iPhone calma, precisa e reconhecível. Grafite com fundo levemente verde, contraste de lima e números grandes. Modo claro em branco suave. Nome sempre **FitΛ**; identificadores técnicos usam FitLambda.

## Paleta

| Papel | Escuro | Claro |
| --- | --- | --- |
| Fundo | #101410 | #F5F6EF |
| Superfície | #1A201A | #FFFFFF |
| Linha | #30372E | #DDE2D5 |
| Destaque | #D4F68A | #496D1F |
| Texto secundário | #9BA494 | #697560 |
| Coração | #F4B4AC | #9E514D |
| Sono | #C6BAF5 | #706092 |

## Telas

1. **Hoje:** saudação, identificação da pulseira, arco de passos, distância, energia ativa, minutos em movimento, coração e sono. Detalhes abrem em folhas modais.
2. **Evolução:** histórico, período e comparação visual. Na prévia web, há métricas de passos, sono e coração e seleção das barras. A base SwiftUI contém o gráfico de passos semanal e mensal.
3. **Pulseira:** ilustração conceitual, bateria de exemplo, fluxo de conexão simulado, três conceitos de mostrador e contexto de sincronização.
4. **Perfil:** nome, meta, aparência, lembretes simulados, privacidade e introdução.
5. **Boas-vindas:** assinatura Λ e apresentação curta antes de explorar o app.

## Comportamento

- Navegação principal sempre disponível; sistema nativo TabView na base SwiftUI.
- Cards arredondados, transições breves; prévia web respeita redução de movimento.
- Modal com Escape, bloqueio de foco do fundo, retorno de foco e botão de fechar.
- A prévia web guarda somente nome, meta, aparência e conceito de mostrador no armazenamento local do navegador. A base SwiftUI mantém preferências em memória.
- No celular a moldura editorial desaparece e a interface ocupa a tela.
- Dados marcados como demonstração. Não se apresentam sinais como medições reais nem se classificam resultados como saudáveis.

## Limites desta entrega

É uma interface navegável, não uma publicação na App Store. Não contém autenticação Samsung, sincronização BLE, notificações reais, HealthKit ou envio de mostradores. Bateria, atividade, frequência e sono são amostras fictícias. Os mostradores são conceitos, não arquivos instaláveis na Fit3.

A pasta `ble_lab` permanece igual à versão 0.1.0. A disponibilidade das informações desenhadas deverá ser validada no protocolo antes de virar compromisso de produto.

## Referências de plataforma

- https://developer.apple.com/design/human-interface-guidelines/tab-bars
- https://developer.apple.com/design/human-interface-guidelines/layout

## Validação

A prévia HTML/CSS/JavaScript foi revisada no navegador e verificada sintaticamente. A base SwiftUI é fonte inicial de interface e precisa de compilação e revisão no Xcode/macOS: este ambiente Windows/Linux não contém o SDK iOS. Não foi produzida uma IPA nem realizado teste em iPhone físico.

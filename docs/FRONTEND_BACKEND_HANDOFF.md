# FitΛ — acordo entre interface e integração

Proposta de contrato v0.1 · 15/11/2026.

Este documento organiza o trabalho dos dois chats. Não implementa BLE nem altera a lógica da pulseira. O visual aprovado na versão 0.2.0 é a referência. O contrato deverá ser alinhado com os dados realmente observados na Fit3.

## Responsabilidade de cada frente

| Frente | Entrega |
| --- | --- |
| Interface, neste chat | SwiftUI, navegação, componentes, acessibilidade, animações, estados de tela, fluxo de permissões, apresentação dos dados, identidade e materiais visuais |
| Integração, no outro chat | Descoberta BLE, pareamento, autenticação, protocolo, leitura/escrita, reconexão, sincronização e validação das capacidades da Fit3 e do iOS |
| Encontro das frentes | Substituir a fonte simulada por um adaptador com os mesmos dados e estados; compilar e testar novamente no iPhone |

## Regra para as telas

A camada visual recebe um estado pronto para exibir e envia intenções de ação. Ela não conhece UUIDs GATT, mensagens Samsung, chaves ou pacotes BLE. O provedor traduz esses detalhes para o contrato de interface.

Próxima refatoração: extrair os números de demonstração hoje espalhados nas views para uma fonte única de estado. `DemoStore` continua como fonte simulada até essa refatoração. O contrato abaixo ainda não está conectado às views.

## Estado comum proposto

| Campo | Tipo/semântica |
| --- | --- |
| schemaVersion | Inteiro, inicialmente 1 |
| origin | `demo` ou `device`; a UI sempre identifica demonstrações |
| device.id | Identificador opaco estável; pode ser nulo antes da seleção |
| device.name / model | Nome legível / modelo observado |
| device.batteryPercent | Inteiro de 0 a 100 ou nulo quando não recebido |
| connection.phase | `unpaired`, `discovering`, `deviceFound`, `pairing`, `authenticating`, `connected`, `disconnected` ou `error` |
| connection.lastSeenAt | ISO 8601 UTC ou nulo |
| connection.message | Mensagem curta traduzível, sem segredos ou identificadores desnecessários |
| sync.phase | `idle`, `running`, `complete`, `partial` ou `failed` |
| sync.lastCompletedAt | ISO 8601 UTC ou nulo; preservar o último sucesso quando uma nova tentativa falhar |
| sync.progress | Número de 0 a 1 ou nulo quando o total é desconhecido |
| metrics.steps | Número de passos do dia ou nulo |
| metrics.distanceMeters | Distância em metros ou nulo |
| metrics.activeEnergyKcal | Energia ativa em kcal ou nulo; não confundir com energia total |
| metrics.activeMinutes | Minutos ativos ou nulo |
| metrics.heartRate | `bpm`, `measuredAt` e `context` (`resting`, `current`, `unknown`), ou nulo |
| metrics.sleep | Início/fim, duração dormindo em segundos e fases opcionais, ou nulo |
| metrics.day / timeZone | Dia local `YYYY-MM-DD` e zona IANA utilizada na agregação |
| capabilities | Mapa de capacidades e disponibilidade descrito abaixo |

Todos os valores ausentes aparecem como “Sem dados”. Um zero verdadeiro permanece zero. Dados anteriores podem continuar visíveis com a informação de quando foram atualizados. A interface não deve inventar medições nem transformar perda de conexão em perda de histórico.

## Capacidades da proposta

Cada capacidade recebe `unverified`, `supported`, `unsupported` ou `requiresPermission`. O estado da permissão fica em um campo separado (`notRequested`, `granted`, `denied`, `restricted`), quando aplicável. Permissão concedida não transforma uma capacidade não verificada em suporte comprovado.

| ID | Recurso da proposta | O que a interface prepara |
| --- | --- | --- |
| bleConnection | Conexão BLE | Busca, seleção, conectada, desconectada, erro e retomada |
| fullPairing | Pareamento completo | Etapas e confirmação verdadeira após resposta do provedor |
| healthSync | Apple Saúde | Categorias, permissões e último envio |
| notifications | Notificações | Preferências e estado de disponibilidade da ponte de notificações |
| bandSettings | Configurações da pulseira | Controles habilitados individualmente conforme suporte confirmado |
| mediaControls | Música / Apple Music | Apresentação dos controles que a integração conseguir suportar; não pressupõe reprodução independente na pulseira |
| weather | Clima | Localidade, permissão quando necessária e idade da informação |
| cameraRemote | Controle de câmera | Entrada, contagem e resultado; compatibilidade ainda a validar |
| bluetoothDiagnostics | Diagnóstico Bluetooth | Estado, potência do sinal quando disponível, versão e eventos explicáveis |
| rawDataExport | Exportação de dados brutos | Seleção do conteúdo, prévia e compartilhamento; excluir chaves e segredos por padrão |
| sleepInsights | Análise do sono | Duração, regularidade e fases disponíveis; metodologia explícita, sem interpretação clínica automática |
| connectionMonitoring | Monitoramento da conexão | Linha do tempo, falhas, reconexões e último sucesso |

## Ações enviadas pela interface

`beginDiscovery`, `selectDevice`, `confirmPairing`, `cancelPairing`, `requestSync`, `requestPermission`, `updateSupportedSetting`, `requestExport` e `forgetDevice` são intenções. Cada integração responde com `success`, `inProgress`, `unsupported`, `permissionRequired`, `cancelled` ou `failed` e um código estável.

Definir o transporte concreto dessas intenções em Swift somente após alinhar o provedor. Não tratar um toque no botão como confirmação de efeito físico.

## Cenários de aprovação visual

1. Primeiro acesso, sem pulseira e sem histórico.
2. Permissão Bluetooth não solicitada, negada e concedida.
3. Nenhuma pulseira encontrada; busca pode ser repetida ou cancelada.
4. Pareamento e autenticação em andamento, sucesso, cancelamento e erro recuperável.
5. Pulseira conectada com métricas completas.
6. Sincronização parcial: passos chegaram, sono ainda ausente.
7. Pulseira desconectada com histórico anterior preservado.
8. Bateria baixa, dado antigo e falha de sincronização são informações diferentes.
9. Recurso não suportado com explicação curta, sem botão que prometa funcionar.
10. Texto ampliado, leitor de tela, modo claro/escuro e redução de movimento.

## Mensagem pronta para o outro chat

“Estamos preservando a identidade visual aprovada do FitΛ. A frente de interface está em SwiftUI com dados simulados. Use este contrato como proposta de integração: informe quais métricas e comandos foram comprovados, as unidades, os estados de conexão/sincronização e as capacidades suportadas. Mantenha BLE e protocolo fora das views. Envie um exemplo de estado sem chaves/segredos e a referência do código testado. Vamos alinhar o adaptador antes de substituir os dados de demonstração.”

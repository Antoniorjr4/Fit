# Verificação da interface — 15/11/2026

## Verificado na prévia web

- Navegação das quatro áreas e atualização do estado da barra inferior.
- Meta alterada para 6.000: indicador mostra 141%, arco limitado ao círculo completo e texto de meta alcançada; consistência recalculada para 7 de 7 dias.
- Fluxo de conexão com três etapas e confirmação explicitamente simulada.
- Escolha do mostrador Essencial altera a ilustração; seleção só é efetivada ao confirmar.
- Alternância de aparência para claro e restauração das preferências.
- Tela de evolução: período mensal, métrica sono, seleção de barra e valor correspondente.
- Detalhe do sono: fases, tempos e indicação de dados fictícios.
- Modal exclui fundo do foco e contém controle de fechamento.
- Layouts de 320 × 740 e 390 × 844 sem rolagem horizontal: scrollWidth igual a clientWidth.
- Revisão visual em navegador desktop e nos dois tamanhos de celular.
- Sintaxe JavaScript verificada com node --check.
- Arquivos ble_lab/probe.py, requirements.txt e docs/TEST_PLAN.md iguais, byte a byte, à versão 0.1.0.

## Limites

- Não houve compilação SwiftUI ou execução no simulador iOS: SDK e Xcode indisponíveis neste ambiente Linux.
- Não houve teste no iPhone físico, conexão Bluetooth ou integração HealthKit.
- A base SwiftUI cobre a direção visual; a prévia web tem interações de gráfico adicionais descritas no documento de design.

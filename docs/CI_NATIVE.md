# Primeira validação nativa

Frente de interface do FitΛ. Repositório: `Antoniorjr4/Fit`.

## Resultado esperado

1. Gerar um projeto Xcode a partir de `ios/project.yml`.
2. Compilar a fonte SwiftUI para o simulador, sem assinatura de distribuição.
3. Instalar e abrir o app em um simulador de iPhone com iOS 17 ou posterior.
4. Capturar a tela nativa e publicar logs/artefato do simulador no run.

## Disparo

Pull requests contra `main`, limitados aos caminhos de interface nativa e configuração de CI, além da execução manual quando o workflow já estiver na branch padrão. Não há disparo em qualquer push indiscriminadamente. O checkout usa o SHA exato da branch do pull request.

## Limites da evidência

Um build verde com captura comprova a compilação e uma abertura no simulador. Não comprova uso em iPhone físico, integração Bluetooth, envio de dados ao Apple Saúde, todas as interações ou aprovação na App Store. Esses resultados devem ser registrados em etapas próprias.

## Saídas

Os artefatos ficam disponíveis por 7 dias. A captura e os logs relevantes poderão ser preservados no projeto após a revisão, sem chaves ou credenciais.

## Relação com as versões anteriores

Os documentos de preparação 0.2.1 registram o estágio anterior, quando o fluxo era apenas manual e o GitHub ainda não estava operacional nesta sessão. Este documento e o workflow atual descrevem o comportamento do repositório GitHub.

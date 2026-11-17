# Compilação e validação nativa

Frente de interface do FitΛ. Repositório: `Antoniorjr4/Fit`.

## Resultado confirmado

O [run 6](https://github.com/Antoniorjr4/Fit/actions/runs/43851101290) concluiu com sucesso em 16/11/2026 (UTC), no código `16ca247fa33e4600dd55be224dddc779df7ee7c3`: compilação, instalação, abertura e nove execuções de testes aprovadas. Foram sete no iPhone 16 Pro Max e duas no iPhone SE (3ª geração), com iOS 18.5 e Xcode 16.4. Nenhuma falha ou teste ignorado.

A [galeria 0.3.0](validation/ui-0.3.0/README.md) preserva capturas originais, resumos do XCTest e identificação da execução. O [registro do primeiro build](validation/native-ui-2026-11-16.md) permanece como histórico.

## Etapas do workflow

1. Gerar um projeto Xcode a partir de `ios/project.yml`.
2. Compilar a fonte SwiftUI para o simulador, sem assinatura de distribuição.
3. Instalar e abrir o app em um simulador de iPhone com iOS 17 ou posterior.
4. Capturar a tela nativa e publicar logs/artefato do simulador no run.
5. Executar [as jornadas de interface](UI_JOURNEYS.md) no iPhone 16 Pro Max e repetir meta/texto ampliado no iPhone SE (3ª geração).
6. Exportar os resultados XCTest e as capturas das quatro abas, dos dois temas e dos estados selecionados.

## Disparo

Pull requests contra `main`, limitados aos caminhos de interface nativa e configuração de CI, além da execução manual quando o workflow já estiver na branch padrão. Não há disparo em qualquer push indiscriminadamente. O checkout usa o SHA exato da branch do pull request.

## Limites da evidência

O run 6 verificou as ações descritas em `UI_JOURNEYS.md` nos dois modelos de simulador. As capturas selecionadas foram revisadas quanto a enquadramento, quebras de texto e consistência dos temas. Isso não comprova uso em iPhone físico, VoiceOver, todas as categorias de Dynamic Type, iOS 17, integração Bluetooth, envio de dados ao Apple Saúde ou aprovação na App Store. Esses resultados devem ser registrados em etapas próprias.

## Saídas

Os artefatos ficam disponíveis por 7 dias e incluem os resultados completos de XCTest, resumos JSON e capturas exportadas. As imagens selecionadas e o registro da execução ficam preservados no projeto após a revisão.

## Relação com as versões anteriores

Os documentos de preparação 0.2.1 registram o estágio anterior, quando o fluxo era apenas manual e o GitHub ainda não estava operacional nesta sessão. Este documento e o workflow atual descrevem o comportamento do repositório GitHub.

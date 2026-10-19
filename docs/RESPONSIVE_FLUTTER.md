# Padrão responsivo do app Flutter

O app usa três faixas de layout centralizadas em `app/lib/shared/layout/responsive.dart`:

- **Compacto:** menos de 600 px — celular em retrato.
- **Médio:** de 600 a 899 px — celular em paisagem e tablets menores.
- **Expandido:** 900 px ou mais — tablet amplo e desktop.

## Como criar telas novas

1. Use `ResponsiveBreakpoints.of(context)` ou `ResponsiveBuilder` em vez de criar breakpoints locais.
2. Envolva o conteúdo principal com `ResponsivePagePadding` para manter margens e largura máxima consistentes.
3. Use `ResponsiveGrid` para cards que precisam mudar de uma para várias colunas.
4. Prefira `Expanded`, `Flexible`, `Wrap` e `TextOverflow.ellipsis` a larguras fixas.
5. Em telas compactas, troque `Row` por `Column` ou `Wrap` quando os controles não couberem.
6. Dê no mínimo 48 px de área de toque para botões e itens de navegação.

## O que fica automático

`ResponsiveNavShell` já escolhe navegação inferior no celular e barra superior em telas amplas. Componentes compartilhados como `PremiumPage` também ajustam padding, espaçamento e largura máxima.

Isso não torna qualquer código arbitrário automaticamente responsivo: uma tela nova ainda precisa usar os componentes responsivos e evitar dimensões rígidas. O padrão reduz a repetição e mantém as decisões principais consistentes.

## Validação

- Testar larguras aproximadas de 360, 600, 768, 900 e 1440 px.
- Testar teclado aberto e orientação paisagem.
- Verificar overflow no console e textos longos.
- Rodar `flutter analyze` e os testes relacionados.

# Changelog

## 1.0.0

### Bug fixes (breaking behavior changes)

- **`Calendar#build`**: o segundo `while` checava `start_date.wday == 6` no lugar de `end_date.wday == 6` (copy-paste). Com isso, `@end_date` podia terminar num sábado sem feriado explícito, gerando entradas `nil` em `@business_dates` e fazendo `adjust(:following)` e `advance` retornarem `nil` silenciosamente em datas no fim do range.

- **`Calendar#advance`**: para `n` positivo grande o suficiente para que `adjusted_date_index(date) + n` ultrapassasse o tamanho de `@business_dates`, o método retornava `nil` silenciosamente. Agora reconstrói o calendário simetricamente ao caso `n` negativo. Resolve o cenário onde fundos com `redemption_conversion_days` alto (ex.: 270) produziam datas nulas.

- **`Calendar#networkdays`**: agora levanta `ArgumentError` quando `date1 > date2`, em vez de devolver valor negativo silencioso. Comportamento documentado mas não enforçado anteriormente.

### Behavior changes (non-breaking)

- **`Calendar#range_check`**: expansão para trás passou de 2 dias para 252 dias (simétrico com a expansão para frente). Elimina reconstruções repetidas em consultas batch retroativas.

- **`Calendar#advance`**: recursão para `n` muito negativo agora converge em uma única reconstrução (folga 2x sobre dias úteis pedidos), em vez de múltiplas iterações reconstruindo todo o calendário.

- **Thread-safety**: métodos públicos protegidos por `Monitor` (reentrante). Múltiplas threads agora podem chamar `advance`, `adjust`, `networkdays`, `is_holiday?` e `last_day_of_previous_month` simultaneamente sem corromper estado interno durante reconstruções.

- **Cópia defensiva de `holidays`**: a lista de feriados passada ao construtor agora é `dup.freeze`. Mutações externas pós-construção não afetam mais o estado interno.

- **`Calendar#last_day_of_previous_month`**: reescrito de forma legível usando `Date.civil(year, month, 1) - 1`, sem mudança de comportamento.

### Doc

- Comentário de `networkdays` reescrito para refletir a semântica real ("saltos entre dias úteis", não contagem inclusiva).

### Dev / build

- Atualizado `bundler` para `>= 2.0` e `rake` para `>= 12.0`. Adicionado `rspec ~> 3.0` como dev dep explícita.
- Removido pin de Ruby 2.4 do `Gemfile`.
- Removidas dev deps `guard-rspec` e `terminal-notifier-guard` (não eram usadas em CI).

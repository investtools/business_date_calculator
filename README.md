# BusinessDateCalculator

[![CI](https://github.com/investtools/business_date_calculator/actions/workflows/ci.yml/badge.svg)](https://github.com/investtools/business_date_calculator/actions/workflows/ci.yml)

Biblioteca Ruby para cálculos com calendário de dias úteis: identificar feriados, mover datas entre dias úteis, contar dias úteis entre datas e ajustar datas não-úteis para o próximo ou anterior dia útil.

Pensada para casos de uso financeiros (cotização e liquidação de fundos, D+N, dias úteis no calendário ANBIMA/B3), mas sem dependências de feriados específicos — você fornece a lista.

## Instalação

Adicione ao `Gemfile`:

```ruby
gem 'business_date_calculator', '~> 1.0'
```

E rode:

```bash
bundle install
```

Ou instale isoladamente:

```bash
gem install business_date_calculator
```

## Uso

### Criando um calendário

```ruby
require 'business_date_calculator'

start_date = Date.parse('2024-01-01')
end_date   = Date.parse('2024-12-31')
holidays   = [Date.parse('2024-01-01'), Date.parse('2024-12-25')]

calendar = BusinessDateCalculator::Calendar.new(start_date, end_date, holidays)
```

O calendário expande automaticamente seu range internamente quando você pergunta por datas fora do intervalo inicial — você não precisa pré-dimensionar.

### `is_holiday?(date)`

Retorna `true` para fins de semana ou datas na lista de feriados:

```ruby
calendar.is_holiday?(Date.parse('2024-01-01'))  # => true  (feriado)
calendar.is_holiday?(Date.parse('2024-01-06'))  # => true  (sábado)
calendar.is_holiday?(Date.parse('2024-01-08'))  # => false (segunda)
```

### `adjust(date, convention)`

Ajusta uma data não-útil para o próximo dia útil (`:following`) ou anterior (`:preceding`). Use `:unadjusted` para devolver a data sem modificar.

```ruby
calendar.adjust(Date.parse('2024-01-06'), :following)   # => 2024-01-08 (segunda)
calendar.adjust(Date.parse('2024-01-06'), :preceding)   # => 2024-01-05 (sexta)
calendar.adjust(Date.parse('2024-01-08'), :following)   # => 2024-01-08 (já é dia útil)
```

### `advance(date, n, convention = :following)`

Avança `n` dias úteis a partir de `date`. Aceita `n` negativo para recuar.

```ruby
calendar.advance(Date.parse('2024-01-08'), 5)    # => 2024-01-15
calendar.advance(Date.parse('2024-01-15'), -3)   # => 2024-01-10
calendar.advance(Date.parse('2024-01-06'), 1)    # => 2024-01-09 (sábado avança para seg + 1)
```

Se `date` cai num dia não-útil, ele é ajustado primeiro segundo a `convention` antes de avançar.

### `networkdays(date1, date2, convention1 = :unadjusted, convention2 = :unadjusted)`

Retorna a contagem de "saltos" entre dias úteis nas duas datas. Equivalente a `índice_util(date2) - índice_util(date1)`:

```ruby
mon = Date.parse('2024-01-08')
fri = Date.parse('2024-01-12')

calendar.networkdays(mon, fri)  # => 4 (segunda→sexta: 4 saltos)
calendar.networkdays(mon, mon)  # => 0 (mesma data)
```

**Levanta `ArgumentError` se `date1 > date2`.**

Se as datas passadas não são úteis, especifique convenções de ajuste:

```ruby
sat = Date.parse('2024-01-06')
fri = Date.parse('2024-01-12')

calendar.networkdays(sat, fri, :following, :unadjusted)  # ajusta sat → mon, depois conta
```

### `last_day_of_previous_month(date)`

Retorna o último dia útil do mês anterior:

```ruby
calendar.last_day_of_previous_month(Date.parse('2024-03-15'))
# => 2024-02-29 (sexta — último dia útil de fevereiro)
```

## Thread-safety

Métodos públicos são protegidos por `Monitor` (reentrante). Múltiplas threads podem chamar métodos da mesma instância concorrentemente sem corrupção de estado durante reconstruções internas.

## Marshal / Rails.cache

A classe implementa `marshal_dump` / `marshal_load` para funcionar com `Rails.cache.fetch` e outros consumidores que serializam via `Marshal`. O `Monitor` interno é recriado fresh na desserialização.

## Desenvolvimento

```bash
bundle install
bundle exec rspec          # roda testes
bundle exec rubocop        # lint
bundle exec bundler-audit  # security audit das deps
```

## Release

1. Atualize `lib/business_date_calculator/version.rb`
2. Atualize `CHANGELOG.md`
3. `bundle exec rake release` — cria tag git, faz push e publica no rubygems.org

## Contribuindo

1. Fork
2. `git checkout -b minha-feature`
3. Adicione testes pra mudança (TDD recomendado)
4. Garanta `bundle exec rspec` e `bundle exec rubocop` passando
5. Pull Request pra `master`

## License

MIT. Veja [LICENSE.txt](LICENSE.txt) (se ausente, MIT padrão).

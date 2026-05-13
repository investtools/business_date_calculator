require 'monitor'

module BusinessDateCalculator
  # Calculadora de dias uteis com calendario customizavel de feriados.
  #
  # Mantem uma estrutura de dados indexada cobrindo um intervalo de datas, expandida
  # dinamicamente quando consultas saem do range inicial. Thread-safe (Monitor reentrante)
  # e Marshal-friendly para uso com Rails.cache.
  #
  # @example Uso basico
  #   holidays = [Date.parse('2024-01-01'), Date.parse('2024-12-25')]
  #   cal = BusinessDateCalculator::Calendar.new(Date.parse('2024-01-01'), Date.parse('2024-12-31'), holidays)
  #   cal.advance(Date.parse('2024-01-08'), 5)   # => 2024-01-15
  class Calendar
    # Cria um novo calendario.
    #
    # @param start_date [Date] data inicial do range (sera ajustada para o dia util anterior se nao for util)
    # @param end_date [Date] data final do range (sera ajustada para o proximo dia util se nao for util)
    # @param holidays [Array<Date>] lista de feriados a considerar como nao-uteis (dup.freeze interno)
    def initialize(start_date, end_date, holidays)
      @monitor = Monitor.new
      build(start_date, end_date, holidays)
    end

    # Verifica se uma data nao e util (fim de semana ou feriado).
    #
    # @param date [Date] data a verificar
    # @return [Boolean] true se for sabado, domingo ou estiver na lista de feriados
    def is_holiday?(date)
      @monitor.synchronize { date.wday.zero? || date.wday == 6 || @holidays.include?(date) }
    end

    # Conta dias uteis entre duas datas como "saltos" no indice de dias uteis.
    # Equivalente a +indice_util(date2) - indice_util(date1)+: mesma data retorna 0,
    # segunda-feira ate sexta-feira da mesma semana retorna 4.
    #
    # @param date1 [Date] data inicial (deve ser menor ou igual a date2)
    # @param date2 [Date] data final
    # @param convention1 [Symbol] convencao de ajuste para date1: +:unadjusted+, +:following+, +:preceding+
    # @param convention2 [Symbol] convencao de ajuste para date2
    # @return [Integer] numero de saltos entre dias uteis
    # @raise [ArgumentError] quando date1 > date2
    #
    # @example
    #   cal.networkdays(Date.parse('2024-01-08'), Date.parse('2024-01-12'))  # => 4
    def networkdays(date1, date2, convention1 = :unadjusted, convention2 = :unadjusted)
      if date1 > date2
        raise ArgumentError,
              "date1 must be less than or equal to date2 (got date1=#{date1}, date2=#{date2})"
      end

      @monitor.synchronize do
        range_check(date1)
        range_check(date2)
        i1 = adjusted_date_index(date1, convention1)
        i2 = adjusted_date_index(date2, convention2)
        raise "Adjusted date1 #{date1} is out of range"  if i1.nil?
        raise "Adjusted date2 #{date2} is out of range"  if i2.nil?

        i2 - i1
      end
    end

    # Ajusta uma data para o dia util mais proximo segundo a convencao indicada.
    # Se a data ja for util, retorna ela inalterada independente da convencao.
    #
    # @param date [Date] data a ajustar
    # @param convention [Symbol] +:following+ (proximo dia util), +:preceding+ (anterior),
    #   ou +:unadjusted+ (devolve a data sem alteracao)
    # @return [Date] data ajustada
    # @raise [RuntimeError] +:preceding+ quando nao ha dia util anterior conhecido
    #
    # @example
    #   cal.adjust(Date.parse('2024-01-06'), :following)  # => 2024-01-08 (sabado -> segunda)
    def adjust(date, convention)
      @monitor.synchronize do
        range_check(date)
        return date if !is_holiday?(date) || convention == :unadjusted

        case convention
        when :following
          @business_dates[@next_business_date_index[date]]
        when :preceding
          raise "Erro pegando data util anterior ao dia #{date}" if @prev_business_date_index[date].nil?

          @business_dates[@prev_business_date_index[date]]
        end
      end
    end

    # Avanca (ou recua) +n+ dias uteis a partir de +date+. Expande o calendario
    # automaticamente quando +n+ extrapola o range conhecido.
    #
    # @param date [Date, #to_date] data de partida
    # @param n [Integer] numero de dias uteis a avancar (negativo para recuar)
    # @param convention [Symbol] convencao para ajustar +date+ caso ela seja nao-util
    # @param margin [Integer] folga em dias corridos para expansao do calendario (uso interno em recursao)
    # @return [Date] dia util resultante
    #
    # @example Avancar 5 dias uteis
    #   cal.advance(Date.parse('2024-01-08'), 5)  # => 2024-01-15
    #
    # @example Recuar 3 dias uteis
    #   cal.advance(Date.parse('2024-01-15'), -3)  # => 2024-01-10
    def advance(date, n, convention = :following, margin = 30)
      @monitor.synchronize do
        date = date.to_date
        range_check(date)
        index = adjusted_date_index(date, convention) + n
        if index.negative?
          # 2x folga sobre dias uteis cobre fins de semana e feriados em uma unica reconstrucao
          build(date + ((index * 2) - margin).days, @end_date, @holidays)
          return advance(date, n, convention, margin + 30)
        elsif index >= @business_dates.length
          overshoot = index - @business_dates.length + 1
          build(@start_date, @end_date + ((overshoot * 2) + margin).days, @holidays)
          return advance(date, n, convention, margin + 30)
        end
        @business_dates[adjusted_date_index(date, convention) + n]
      end
    end

    # Ultimo dia util do mes anterior ao da data passada.
    #
    # @param date [Date] data de referencia
    # @return [Date] ultimo dia util do mes anterior (com ajuste +:preceding+ se for nao-util)
    #
    # @example
    #   cal.last_day_of_previous_month(Date.parse('2024-03-15'))  # => 2024-02-29
    def last_day_of_previous_month(date)
      @monitor.synchronize { adjust(Date.civil(date.year, date.month, 1) - 1, :preceding) }
    end

    # @!group Marshal serialization

    # Monitor nao e serializavel via Marshal (Rails.cache usa Marshal). Pula o monitor
    # na serializacao e recria fresh na deserializacao.
    # @api private
    def marshal_dump
      {
        start_date: @start_date,
        end_date: @end_date,
        holidays: @holidays,
        business_dates: @business_dates,
        business_date_index: @business_date_index,
        next_business_date_index: @next_business_date_index,
        prev_business_date_index: @prev_business_date_index
      }
    end

    # @api private
    def marshal_load(data)
      @monitor = Monitor.new
      @start_date = data[:start_date]
      @end_date = data[:end_date]
      @holidays = data[:holidays]
      @business_dates = data[:business_dates]
      @business_date_index = data[:business_date_index]
      @next_business_date_index = data[:next_business_date_index]
      @prev_business_date_index = data[:prev_business_date_index]
    end

    # @!endgroup

    protected

    def build(start_date, end_date, holidays)
      holidays = holidays.dup.freeze
      # garante que start_date e end_date sao dias uteis
      start_date -= 1.days while start_date.wday.zero? || start_date.wday == 6 || holidays.include?(start_date)
      end_date += 1.days while end_date.wday.zero? || end_date.wday == 6 || holidays.include?(end_date)

      @start_date = start_date
      @end_date = end_date
      @holidays = holidays
      @business_dates = []
      @business_date_index = {}
      @next_business_date_index = {}
      @prev_business_date_index = {}

      d = start_date
      i = 0
      while d <= end_date
        if is_holiday?(d)
          # dia não útil, mapeia o indice do dia util anterior e proximo
          @next_business_date_index[d] = i
          @prev_business_date_index[d] = i - 1
        else
          # dia util, adiciona ao final do array, e mapeia o indice do array no mapa
          @business_dates << d
          @business_date_index[d] = i
          i += 1
        end
        d += 1.days
      end
    end

    EXPANSION_MARGIN_DAYS = 252

    # Verifica se a data passada esta entre o periodo desta instancia.
    # Quando fora do range, reconstroi simetricamente com EXPANSION_MARGIN_DAYS dias de folga
    # para evitar rebuilds em sequencia em consultas em batch.
    def range_check(date)
      if date < @start_date
        build(date - EXPANSION_MARGIN_DAYS.days, @end_date, @holidays)
      elsif date > @end_date
        build(@start_date, date + EXPANSION_MARGIN_DAYS.days, @holidays)
      end
    end

    def adjusted_date_index(date, convention)
      @business_date_index[adjust(date, convention)]
    end
  end
end

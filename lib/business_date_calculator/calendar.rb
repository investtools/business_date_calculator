require 'monitor'

module BusinessDateCalculator
  class Calendar

    # Constroi a estrutura de dados a partir de uma lista de holidays que
    # sao os feriados, e usando um periodo especificado (fechado nas duas pontas).
    def initialize(start_date, end_date, holidays)
      @monitor = Monitor.new
      build(start_date, end_date, holidays)
    end

    def is_holiday?(date)
      @monitor.synchronize { date.wday == 0 || date.wday == 6 || @holidays.include?(date) }
    end

    # Retorna a contagem de "saltos" entre dias uteis nas duas datas especificadas.
    # Equivalente a (indice_util(date2) - indice_util(date1)). Para mesma data, retorna 0;
    # para segunda-feira ate sexta-feira da mesma semana, retorna 4.
    # Caso uma das datas nao seja dia util, deve ser especificada uma convencao de ajuste.
    # date1 deve ser menor ou igual a date2.
    def networkdays(date1, date2, convention1 = :unadjusted, convention2 = :unadjusted)
      raise ArgumentError, "date1 must be less than or equal to date2 (got date1=#{date1}, date2=#{date2})" if date1 > date2

      @monitor.synchronize do
        range_check(date1)
        range_check(date2)
        i1 = adjusted_date_index(date1, convention1)
        i2 = adjusted_date_index(date2, convention2)
        raise "Adjusted date1 #{date1} is out of range"  if i1 == nil
        raise "Adjusted date2 #{date2} is out of range"  if i2 == nil
        i2 - i1
      end
    end

    def adjust(date, convention)
      @monitor.synchronize do
        range_check(date)
        if not is_holiday?(date)
          date
        elsif convention == :unadjusted
          date
        else
          case convention
            when :following
              @business_dates[@next_business_date_index[date]]
            when :preceding
              raise "Erro pegando data util anterior ao dia #{date}"  if @prev_business_date_index[date] == nil
              @business_dates[@prev_business_date_index[date]]
          end
        end
      end
    end

    def advance(date, n, convention = :following, margin = 30)
      @monitor.synchronize do
        date = date.to_date
        range_check(date)
        index = adjusted_date_index(date, convention) + n
        if index < 0
          # 2x folga sobre dias uteis cobre fins de semana e feriados em uma unica reconstrucao
          build(date + (index * 2 - margin).days, @end_date, @holidays)
          return advance(date, n, convention, margin + 30)
        elsif index >= @business_dates.length
          overshoot = index - @business_dates.length + 1
          build(@start_date, @end_date + (overshoot * 2 + margin).days, @holidays)
          return advance(date, n, convention, margin + 30)
        end
        @business_dates[adjusted_date_index(date, convention) + n]
      end
    end

    def last_day_of_previous_month(date)
      @monitor.synchronize { adjust(Date.civil(date.year, date.month, 1) - 1, :preceding) }
    end

    # Monitor nao e serializavel via Marshal (Rails.cache usa Marshal). Pula o monitor
    # na serializacao e recria fresh na deserializacao.
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

    protected

    def build(start_date, end_date, holidays)
      holidays = holidays.dup.freeze
      # garante que start_date e end_date sao dias uteis
      while start_date.wday == 0 || start_date.wday == 6 || holidays.include?(start_date) do
        start_date -= 1.days
      end
      while end_date.wday == 0 || end_date.wday == 6 || holidays.include?(end_date) do
        end_date += 1.days
      end

      @start_date = start_date
      @end_date = end_date
      @holidays = holidays
      @business_dates = []
      @business_date_index = {}
      @next_business_date_index = {}
      @prev_business_date_index = {}
      
      d = start_date
      i = 0
      while d <= end_date do
        if is_holiday?(d)
          # dia não útil, mapeia o indice do dia util anterior e proximo
          @next_business_date_index[d] = i
          @prev_business_date_index[d] = i - 1
        else
          # dia util, adiciona ao final do array, e mapeia o indice do array no mapa
          @business_dates << d
          @business_date_index[d] = i
          i = i + 1
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
module BusinessDateCalculator
  class Calendar

    # Constroi a estrutura de dados a partir de uma lista de holidays que
    # sao os feriados, e usando um periodo especificado (fechado nas duas pontas).
    def initialize(start_date, end_date, holidays)
      build(start_date, end_date, holidays)
    end

    def is_holiday?(date)
      date.wday == 0 || date.wday == 6 || @holidays.include?(date)
    end

    # Retorna o numero de dias uteis entre as duas data especificadas, inclusive.
    # As duas datas devem ser dias uteis, ou caso não seja, deve ser 
    # especificado uma convenção de ajuste para cada data.
    # A primeira data deve ser menor ou igual a segunda.
    def networkdays(date1, date2, convention1 = :unadjusted, convention2 = :unadjusted)
      range_check(date1)
      range_check(date2)
      i1 = adjusted_date_index(date1, convention1)
      i2 = adjusted_date_index(date2, convention2)
      raise "Adjusted date1 #{date1} is out of range"  if i1 == nil
      raise "Adjusted date2 #{date2} is out of range"  if i2 == nil
      i2 - i1
    end

    def adjust(date, convention)
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

    def advance(date, n, convention = :following)
      date = date.to_date
      range_check(date)
      @business_dates[adjusted_date_index(date, convention) + n]
    end

    def last_day_of_previous_month(date)
      m = date.month
      y = date.year
      if m == 1
        m = 0
        y = y -1
      end
      adjust(Date.civil(y, (m - 1), -1), :preceding)
    end

    protected

    def build(start_date, end_date, holidays)
      # garante que start_date e end_date sao dias uteis
      while start_date.wday == 0 || start_date.wday == 6 || holidays.include?(start_date) do
        start_date -= 1.days
      end
      while end_date.wday == 0 || start_date.wday == 6 || holidays.include?(end_date) do
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
    
    # Verifica se a data passada esta entre o periodo desta instancia.
    def range_check(date)
      if date < @start_date
        # puts "Reconstruindo calculadora de feriados pois dia #{date} eh menor que #{@start_date} -> #{@end_date}"
        build(date - 2.days, @end_date, @holidays)
      elsif date > @end_date
        # puts "Reconstruindo calculadora de feriados pois dia #{date} eh maior que #{end_date}"
        build(@start_date, date + 252.days, @holidays)
      end
    end
    
    def adjusted_date_index(date, convention)
      @business_date_index[adjust(date, convention)]
    end
  end
end
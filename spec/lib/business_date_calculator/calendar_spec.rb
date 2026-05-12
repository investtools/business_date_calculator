require './spec/spec_helper'
require 'business_date_calculator/calendar'

describe BusinessDateCalculator::Calendar do

  let(:start_date) { Date.parse('2014-12-01') }
  let(:end_date) { Date.parse('2015-02-01') }
  let(:business_date_calculator) { BusinessDateCalculator::Calendar.new(start_date, end_date, [Date.parse('2015-01-01')]) }
  describe '#is_holiday' do
    it 'returns false when is thursday' do
      expect(business_date_calculator.is_holiday?(Date.parse('2015-01-02'))).to be(false)
    end
    it 'returns true when is saturday' do
      expect(business_date_calculator.is_holiday?(Date.parse('2015-01-03'))).to be(true)
    end
    it 'returns true when is holiday' do
      expect(business_date_calculator.is_holiday?(Date.parse('2015-01-01'))).to be(true)
    end
    it 'returns friday if its sunday' do
      expect(business_date_calculator.adjust(Date.parse('2015-06-07'), :preceding)).to eq(Date.parse('2015-06-05'))
    end
  end
  describe '#adjust' do
    it 'returns the next date' do
      expect(business_date_calculator.adjust(Date.parse('2015-01-03'), :following)).to eq(Date.parse('2015-01-05'))
    end
    it 'returns the next date' do
      expect(business_date_calculator.adjust(Date.parse('2015-01-01'), :following)).to eq(Date.parse('2015-01-02'))
    end
    it 'returns the previous date' do
      expect(business_date_calculator.adjust(Date.parse('2015-01-01'), :preceding)).to eq(Date.parse('2014-12-31'))
    end
  end
  describe '#networkdays' do
    it 'returns the number of work days' do
      expect(business_date_calculator.networkdays(Date.parse('2015-01-05'), Date.parse('2015-01-09'))).to eq(4)
    end
    it 'puts into account the holiday' do
      expect(business_date_calculator.networkdays(Date.parse('2014-12-30'), Date.parse('2015-01-09'))).to eq(7)
    end
    it 'raises ArgumentError when date1 is greater than date2' do
      expect {
        business_date_calculator.networkdays(Date.parse('2015-01-09'), Date.parse('2015-01-05'))
      }.to raise_error(ArgumentError, /date1 must be less than or equal to date2/)
    end

    it 'returns 0 when date1 equals date2 (current semantics: workday jumps, not inclusive count)' do
      expect(business_date_calculator.networkdays(Date.parse('2015-01-05'), Date.parse('2015-01-05'))).to eq(0)
    end

    it 'is fast but not like roadrunner' do
      start = (Time.now.to_f.round(3)*1000).to_i
      bdc = BusinessDateCalculator::Calendar.new(Date.parse('2017-01-01'), Date.parse('2017-01-31'), [Date.parse('2017-01-03')])
      jan02 = Date.parse('2017-01-02')
      jan31 = Date.parse('2017-01-31')
      100000.times do |x|
        bdc.networkdays(jan02, jan31)
      end
      puts (Time.now.to_f.round(3)*1000).to_i - start
    end
  end
  describe '#advance' do
    let(:today) { Date.parse('2016-02-17') }
    let(:yesterday) { Date.parse('2016-02-16') }
    it 'returns the date plus n days' do
      expect(business_date_calculator.advance(Date.parse('2014-12-30'), 3, :following)).to eq Date.parse('2015-01-05')
    end
    it 'returns the yesterday' do
      expect(business_date_calculator.advance(today, -1, :following)).to eq yesterday
    end
    it 'returns yesterday' do
      xstart_date = Date.today - 252.days
      xend_date = Date.today + 252.days
      expect(BusinessDateCalculator::Calendar.new(xstart_date, xend_date, []).advance(Date.parse('2016-02-17'), -1, :following)).to eq yesterday
    end
    it 'returns the date 30 days before' do
      result_date = BusinessDateCalculator::Calendar.new(Date.today, Date.today + 5.days, []).advance(Date.parse('2018-01-02'), -30, :following)
      expect(result_date).to eq(Date.parse('2017-11-21'))
    end
  end
  describe '#last_day_of_previous_month' do
    it 'returns the last date of previous month' do
      expect(business_date_calculator.last_day_of_previous_month(Date.parse('2015-01-05'))).to eq Date.parse('2014-12-31')
      expect(business_date_calculator.last_day_of_previous_month(Date.parse('2015-01-01'))).to eq Date.parse('2014-12-31')
      expect(business_date_calculator.last_day_of_previous_month(Date.parse('2015-01-31'))).to eq Date.parse('2014-12-31')
      expect(business_date_calculator.last_day_of_previous_month(Date.parse('2015-02-15'))).to eq Date.parse('2015-01-30')
    end

    it 'handles leap and non-leap February correctly' do
      cal = BusinessDateCalculator::Calendar.new(Date.parse('2019-01-01'), Date.parse('2024-12-31'), [])
      expect(cal.last_day_of_previous_month(Date.parse('2020-03-15'))).to eq Date.parse('2020-02-28')
      expect(cal.last_day_of_previous_month(Date.parse('2021-03-15'))).to eq Date.parse('2021-02-26')
    end

    it 'handles January correctly (crosses year boundary)' do
      cal = BusinessDateCalculator::Calendar.new(Date.parse('2019-01-01'), Date.parse('2024-12-31'), [])
      expect(cal.last_day_of_previous_month(Date.parse('2024-01-15'))).to eq Date.parse('2023-12-29')
    end
  end

  describe 'thread safety' do
    it 'returns valid dates from concurrent advance calls that trigger range expansion' do
      cal = BusinessDateCalculator::Calendar.new(Date.today - 10.days, Date.today + 10.days, [])
      errors = Queue.new
      threads = 8.times.map do |i|
        Thread.new do
          200.times do |j|
            date = Date.today + (j % 5).days
            n = (j.even? ? 1 : -1) * (30 + (j % 50))
            result = cal.advance(date, n, :following)
            errors << "thread #{i} got nil" if result.nil?
            errors << "thread #{i} got non-Date #{result.class}" unless result.is_a?(Date)
          rescue => e
            errors << "thread #{i}: #{e.class}: #{e.message}"
          end
        end
      end
      threads.each(&:join)
      expect(errors.size).to eq(0), "errors found: #{Array.new(errors.size) { errors.pop }.first(5).inspect}"
    end
  end

  describe 'defensive copy of holidays' do
    it 'does not allow external mutation of the holidays array to affect the calendar' do
      holidays = [Date.parse('2015-01-01')]
      cal = BusinessDateCalculator::Calendar.new(Date.parse('2015-01-05'), Date.parse('2015-01-09'), holidays)
      holidays << Date.parse('2015-01-07')
      expect(cal.is_holiday?(Date.parse('2015-01-07'))).to be(false)
    end
  end

  describe '#range_check expansion' do
    it 'extends backward sufficiently for repeated backward queries' do
      cal = BusinessDateCalculator::Calendar.new(Date.parse('2026-01-01'), Date.parse('2026-01-31'), [])
      reference = BusinessDateCalculator::Calendar.new(Date.parse('2024-01-01'), Date.parse('2026-01-31'), [])
      probe = Date.parse('2024-06-03')

      expect(cal.adjust(probe, :following)).to eq(reference.adjust(probe, :following))
      expect(cal.networkdays(probe, Date.parse('2024-06-10'))).to eq(reference.networkdays(probe, Date.parse('2024-06-10')))
    end

    it 'extends forward sufficiently for repeated forward queries' do
      cal = BusinessDateCalculator::Calendar.new(Date.parse('2026-01-01'), Date.parse('2026-01-31'), [])
      reference = BusinessDateCalculator::Calendar.new(Date.parse('2026-01-01'), Date.parse('2028-01-31'), [])
      probe = Date.parse('2027-06-03')

      expect(cal.adjust(probe, :following)).to eq(reference.adjust(probe, :following))
    end
  end

  describe '#adjust at the boundaries of the range' do
    it 'returns a valid business date for :following when date is a weekend at end of range' do
      cal = BusinessDateCalculator::Calendar.new(Date.parse('2015-01-05'), Date.parse('2015-01-09'), [])
      expect(cal.adjust(Date.parse('2015-01-10'), :following)).to eq(Date.parse('2015-01-12'))
    end

    it 'returns a valid business date for :preceding when date is a weekend at start of range' do
      cal = BusinessDateCalculator::Calendar.new(Date.parse('2015-01-05'), Date.parse('2015-01-09'), [])
      expect(cal.adjust(Date.parse('2015-01-04'), :preceding)).to eq(Date.parse('2015-01-02'))
    end

    it '@business_dates contains no nil entries after build' do
      cal = BusinessDateCalculator::Calendar.new(Date.parse('2015-01-05'), Date.parse('2015-01-10'), [])
      business_dates = cal.instance_variable_get(:@business_dates)
      expect(business_dates).not_to include(nil)
      expect(business_dates).to all(be_a(Date))
    end
  end

  describe '#advance with large n that overflows the initial range' do
    let(:small_start) { Date.parse('2026-01-01') }
    let(:small_end) { Date.parse('2026-01-31') }
    let(:small_cal) { BusinessDateCalculator::Calendar.new(small_start, small_end, []) }
    let(:large_cal) { BusinessDateCalculator::Calendar.new(small_start - 500.days, small_end + 500.days, []) }

    it 'expands the calendar and returns a valid business date for forward overflow' do
      expected = large_cal.advance(Date.parse('2026-01-05'), 100, :following)
      expect(small_cal.advance(Date.parse('2026-01-05'), 100, :following)).to eq(expected)
    end

    it 'handles n much larger than the initial range size' do
      expected = large_cal.advance(Date.parse('2026-01-05'), 270, :following)
      expect(small_cal.advance(Date.parse('2026-01-05'), 270, :following)).to eq(expected)
    end

    it 'handles large negative n with a single rebuild' do
      expected = large_cal.advance(Date.parse('2026-01-05'), -200, :following)
      expect(small_cal.advance(Date.parse('2026-01-05'), -200, :following)).to eq(expected)
    end
  end

  describe 'edge cases of #build' do
    context 'when end_date falls on a saturday with no explicit holiday' do
      it 'advances @end_date past the weekend to the next business day' do
        cal = BusinessDateCalculator::Calendar.new(Date.parse('2015-01-05'), Date.parse('2015-01-10'), [])
        expect(cal.adjust(Date.parse('2015-01-10'), :following)).to eq(Date.parse('2015-01-12'))
      end
    end

    context 'when end_date falls on a sunday with no explicit holiday' do
      it 'advances @end_date past the weekend to the next business day' do
        cal = BusinessDateCalculator::Calendar.new(Date.parse('2015-01-05'), Date.parse('2015-01-11'), [])
        expect(cal.adjust(Date.parse('2015-01-11'), :following)).to eq(Date.parse('2015-01-12'))
      end
    end
  end
end
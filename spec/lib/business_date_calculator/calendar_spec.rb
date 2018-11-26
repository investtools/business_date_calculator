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
  end
end
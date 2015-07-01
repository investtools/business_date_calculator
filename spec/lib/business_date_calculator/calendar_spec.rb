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
  end
  describe '#advance' do
    it 'returns the date plus n days' do
      expect(business_date_calculator.advance(Date.parse('2014-12-30'), 3, :following)).to eq Date.parse('2015-01-05')
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
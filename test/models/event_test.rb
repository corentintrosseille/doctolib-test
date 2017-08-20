# == Schema Information
#
# Table name: events
#
#  id               :integer          not null, primary key
#  starts_at        :datetime
#  ends_at          :datetime
#  kind             :string
#  weekly_recurring :boolean
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

require 'test_helper'

class EventTest < ActiveSupport::TestCase
  test "one simple test example" do
    Event.create kind: 'opening', starts_at: DateTime.parse("2014-08-04 09:30"), ends_at: DateTime.parse("2014-08-04 12:30"), weekly_recurring: true
    Event.create kind: 'appointment', starts_at: DateTime.parse("2014-08-11 10:30"), ends_at: DateTime.parse("2014-08-11 11:30")

    availabilities = Event.availabilities DateTime.parse("2014-08-10")
    assert_equal Date.new(2014, 8, 10), availabilities[0][:date]
    assert_equal [], availabilities[0][:slots]
    assert_equal Date.new(2014, 8, 11), availabilities[1][:date]
    assert_equal ["9:30", "10:00", "11:30", "12:00"], availabilities[1][:slots]
    assert_equal Date.new(2014, 8, 16), availabilities[6][:date]
    assert_equal 7, availabilities.length
  end

  test 'valid event' do
    event = Event.new(kind: 'opening', starts_at: DateTime.parse("2014-08-04 09:30"), ends_at: DateTime.parse("2014-08-04 12:30"))
    assert event.valid?
  end

  test 'invalid without starts_at minutes round' do
    event = Event.new(kind: 'opening', starts_at: DateTime.parse("2014-08-04 09:31"), ends_at: DateTime.parse("2014-08-04 12:30"))
    event.valid?
    assert_equal 'minutes must be 0 or 30', event.errors[:starts_at].first
  end

  test 'invalid without ends_at seconds round' do
    event = Event.new(kind: 'opening', starts_at: DateTime.parse("2014-08-04 09:30"), ends_at: DateTime.parse("2014-08-04 12:30:42"))
    event.valid?
    assert_equal 'seconds must be 0', event.errors[:ends_at].first
  end

  test '#availabilities with overlaping events' do
    Event.create kind: 'opening', starts_at: DateTime.parse("2015-08-04 09:30"), ends_at: DateTime.parse("2015-08-04 11:00")
    Event.create kind: 'opening', starts_at: DateTime.parse("2015-08-04 10:30"), ends_at: DateTime.parse("2015-08-04 12:30")

    availabilities = Event.availabilities DateTime.parse("2015-08-04")
    assert_equal Date.new(2015, 8, 04), availabilities[0][:date]
    assert_equal 7, availabilities[0][:slots].count
    assert_equal 7, availabilities.length
  end

  test '#availabilities view no events' do
    availabilities = Event.availabilities DateTime.parse("2016-08-04")
    assert_equal [], availabilities.map{ |availability| availability[:slots] }.flatten
    assert_equal 7, availabilities.length
  end

  test '#availabilities with appointment for all dates' do
    Event.create kind: 'opening', starts_at: DateTime.parse("2017-08-04 09:30"), ends_at: DateTime.parse("2017-08-04 11:00")
    Event.create kind: 'opening', starts_at: DateTime.parse("2017-08-05 09:30"), ends_at: DateTime.parse("2017-08-05 11:00")
    Event.create kind: 'opening', starts_at: DateTime.parse("2017-08-06 09:30"), ends_at: DateTime.parse("2017-08-06 11:00")
    Event.create kind: 'appointment', starts_at: DateTime.parse("2017-08-04 08:00"), ends_at: DateTime.parse("2017-08-06 12:30")

    availabilities = Event.availabilities DateTime.parse("2017-08-04")
    assert_equal [], availabilities.map{ |availability| availability[:slots] }.flatten
    assert_equal 7, availabilities.length
  end

  test '#availabilities with one free slot' do
    Event.create kind: 'opening', starts_at: DateTime.parse("2018-08-04 09:30"), ends_at: DateTime.parse("2018-08-04 17:00")
    Event.create kind: 'appointment', starts_at: DateTime.parse("2018-08-04 09:30"), ends_at: DateTime.parse("2018-08-04 11:00")
    Event.create kind: 'appointment', starts_at: DateTime.parse("2018-08-04 11:30"), ends_at: DateTime.parse("2018-08-04 17:00")

    availabilities = Event.availabilities DateTime.parse("2018-08-04")
    booked_date = Date.new(2018, 8, 04)
    assert_equal booked_date, availabilities[0][:date]
    assert_equal ['11:00'], availabilities[0][:slots]
    assert_equal 7, availabilities.length
  end
end

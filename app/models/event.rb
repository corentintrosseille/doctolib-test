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

class Event < ActiveRecord::Base

  validate :round_times

  def self.recurring_openings(days = nil)
    recurring_openings_arr = where(kind: 'opening', weekly_recurring: true).order(:starts_at).to_a
    recurring_openings_hash = {}
    if days.present?
      recurring_openings_arr.keep_if do |opening|
        days.include?(opening.starts_at.wday) || days.include?(opening.ends_at.wday)
      end
    end
    recurring_openings_arr.group_by{|opening| opening.starts_at.wday }
  end

  def self.availabilities(search_starts_at = DateTime.now, search_ends_at = search_starts_at + 6.days)
    search_ends_at = search_ends_at.end_of_day
    availabilities = []
    return availabilities if search_starts_at > search_ends_at

    # Handle single time events
    openings = self.where(kind: 'opening', weekly_recurring: [nil, false])
      .where('ends_at > ?', search_starts_at)
      .where('starts_at < ?', search_ends_at).order(:starts_at).to_a

    availabilities_hash = {}
    openings.each do |opening|
      availabilities_hash = create_slots(opening.starts_at, opening.ends_at, availabilities_hash)
    end

    # Handle weekly recurring events
    if (search_ends_at - search_starts_at).to_i < 7
      days_for_search = (search_starts_at..search_ends_at).map{|i| i.wday}
    end

    recurring_openings_hash = recurring_openings(days_for_search)
    (search_starts_at..search_ends_at).each do |search_datetime|
      next unless recurring_openings_hash[search_datetime.wday]

      recurring_openings_hash[search_datetime.wday].each do |opening|
        start_date = DateTime.parse("#{search_datetime.strftime("%F")} #{opening.starts_at.strftime("%H:%M")}")
        end_date = start_date + (opening.ends_at - opening.starts_at).seconds
        availabilities_hash = create_slots(start_date, end_date, availabilities_hash)
      end
    end

    # Handle appointments
    appointments = self.where(kind: 'appointment')
      .where('ends_at > ?', search_starts_at)
      .where('starts_at < ?', search_ends_at).order(:starts_at)

    appointments_hash = {}
    appointments.each do |appointment|
      appointments_hash = create_slots(appointment.starts_at, appointment.ends_at, appointments_hash)
    end

    # Removing appointments from availabilities_hash
    appointments_hash.each do |k,v|
      availabilities_hash[k] = availabilities_hash[k] - v if availabilities_hash[k]
    end

    # Sorting and formating
    availabilities_hash.each do |k,v|
      availabilities_hash[k] = v.sort.map{ |slot| slot.first == '0' ? slot[1..-1] : slot }
    end

    # Creating response hash
    (search_starts_at..search_ends_at).each do |search_datetime|
      current_date = search_datetime.strftime("%F")
      availability = {date: current_date.to_date, slots: (availabilities_hash[current_date] || [])}

      availabilities << availability
    end

    availabilities
  end

  private

    def round_times
      attributes = [:starts_at, :ends_at]
      [starts_at, ends_at].each_with_index do |date, i|
        date = DateTime.parse(date.to_s)
        if ([0, 30] - [date.minute]).size == 2
          errors.add(attributes[i], 'minutes must be 0 or 30')
        end
        if date.second != 0
          errors.add(attributes[i], 'seconds must be 0')
        end
      end
    end

    def self.create_slots(start_time, end_time, slots_hash)
      current_date = start_time
      begin
        date_key = current_date.strftime("%F")
        slots_hash[date_key] ||= []
        slots_hash[date_key] << current_date.strftime("%H:%M")
        current_date = current_date + DEFAULT_SLOT_DURATION.minutes
      end while current_date < end_time
      return slots_hash
    end

end

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

  def self.recuring_openings(days = nil)
    recuring_openings_arr = where(kind: 'opening', weekly_recurring: true).order(:starts_at).to_a
    recuring_openings_hash = {}
    if days.present?
      recuring_openings_arr.keep_if do |opening|
        days.include?(opening.starts_at.wday) || days.include?(opening.ends_at.wday)
      end
    end
    recuring_openings_arr.group_by{|opening| opening.starts_at.wday }
  end

  def self.availabilities(search_starts_at = DateTime.now, search_ends_at = search_starts_at + 6.days)
    default_duration = 30 #minutes
    search_ends_at = search_ends_at.end_of_day
    availabilities = []
    return availabilities if search_starts_at > search_ends_at

    # Handle single time events
    openings = self.where(kind: 'opening', weekly_recurring: [nil, false])
      .where('ends_at > ?', search_starts_at)
      .where('starts_at < ?', search_ends_at).order(:starts_at).to_a

    availabilities_hash = {}
    openings.each do |opening|
      current_date = opening.starts_at
      begin
        date_key = current_date.strftime("%F")
        availabilities_hash[date_key] ||= []
        availabilities_hash[date_key] << current_date.strftime("%H:%M")
        current_date = current_date + default_duration.minutes
      end while current_date < opening.ends_at
    end

    # Handle weekly recurring events
    if (search_ends_at - search_starts_at).to_i < 7
      days_for_search = (search_starts_at..search_ends_at).map{|i| i.wday}
    end

    recuring_openings_hash = recuring_openings(days_for_search)
    (search_starts_at..search_ends_at).each do |search_datetime|
      next unless recuring_openings_hash[search_datetime.wday]

      recuring_openings_hash[search_datetime.wday].each do |opening|
        start_date = DateTime.parse("#{search_datetime.strftime("%F")} #{opening.starts_at.strftime("%H:%M")}")
        end_date = start_date + (opening.ends_at - opening.starts_at).seconds
        current_date = start_date
        begin
          date_key = current_date.strftime("%F")
          availabilities_hash[date_key] ||= []
          availabilities_hash[date_key] << current_date.strftime("%H:%M")
          current_date = current_date + default_duration.minutes
        end while current_date < end_date
      end
    end

    # Handle appointments
    appointments = self.where(kind: 'appointment')
      .where('ends_at > ?', search_starts_at)
      .where('starts_at < ?', search_ends_at).order(:starts_at)

    appointments_hash = {}
    appointments.each do |appointment|
      current_date = appointment.starts_at
      begin
        date_key = current_date.strftime("%F")
        appointments_hash[date_key] ||= []
        appointments_hash[date_key] << current_date.strftime("%H:%M")
        current_date = current_date + default_duration.minutes
      end while current_date < appointment.ends_at
    end

    # Removing appointments from availabilities_hash
    appointments_hash.each do |k,v|
      availabilities_hash[k] = availabilities_hash[k] - v
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

end

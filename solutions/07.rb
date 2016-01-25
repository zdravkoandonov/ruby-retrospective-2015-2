module LazyMode
  def self.create_file(name, &block)
    file = File.new(name)
    file.instance_eval(&block)
    file
  end

  class Date
    attr_reader :year, :month, :day

    def initialize(date_string)
      @year, @month, @day = date_string.split('-').map(&:to_i)
    end

    def to_s
      "%{year}-%{month}-%{day}" % {
        year: @year.to_s.rjust(4, '0'),
        month: @month.to_s.rjust(2, '0'),
        day: @day.to_s.rjust(2, '0')
      }
    end

    def add_days!(days)
      @day += days

      @month += (@day - 1) / 30
      @day = (@day - 1) % 30 + 1

      @year += (@month - 1) / 12
      @month = (@month - 1) % 12 + 1

      self
    end

    def add_days(days)
      new_date = clone

      new_date.add_days!(days)
    end

    def days
      @year * 12 * 30 + (@month - 1) * 30 + @day
    end

    def days_difference(other)
      (days - other.days).abs
    end
  end

  class File
    attr_reader :name, :notes

    def initialize(name)
      @name = name
      @notes = []
    end

    def note(header, *tags, &block)
      new_note = Note.new(@name, header, tags)
      new_note.file = self
      new_note.instance_eval(&block)

      notes << new_note
    end

    class Agenda < Struct.new(:notes)
      def where(status: nil, tag: nil, text: nil)
        selected_notes = notes.select! do |note|
          (!tag || note.tags.include?(tag)) &&
            (!text || note.header.match(text) || note.body.match(text)) &&
              (!status || note.status == status)
        end
        Agenda.new(selected_notes)
      end
    end

    def daily_agenda(date_today)
      notes_for_today = @notes
        .select { |note| note.scheduled_for_today?(date_today) }
        .map { |note| note.with_date(date_today) }
      Agenda.new(notes_for_today)
    end

    def weekly_agenda(date_today)
      dates_this_week = Array.new(7, date_today).zip(0..6).map do |date, days|
        date.add_days(days)
      end
      notes = dates_this_week.map { |date|
        daily_agenda(date).notes }.reduce(:+)
      Agenda.new(notes)
    end
  end

  class Note
    attr_reader :header, :file_name, :tags, :date
    attr_writer :file

    def initialize(file_name, header, tags)
      @file_name = file_name
      @header = header
      @tags = tags
      @status = :topostpone
      @body = ""
    end

    def body(body_to_set = nil)
      if body_to_set
        @body = body_to_set
      else
        @body
      end
    end

    def status(status_to_set = nil)
      if status_to_set
        @status = status_to_set
      else
        @status
      end
    end

    def with_date(date_scheduled)
      @date = date_scheduled
      self
    end

    def note(header, *tags, &block)
      @file.note(header, *tags, &block)
    end

    def scheduled(date_string_with_repetition)
      date_string, repetition_string = date_string_with_repetition.split
      @date = Date.new(date_string)
      if repetition_string
        repeat_codes = {'m' => 30, 'w' => 7, 'd' => 1}
        repeat_every = repetition_string[1..-2].to_i
        @repeat_interval = repeat_every * repeat_codes[repetition_string[-1]]
      end
    end

    def scheduled_for_today?(date)
      if @repeat_interval
        @date.days_difference(date) % @repeat_interval == 0
      else
        @date.days_difference(date) == 0
      end
    end
  end
end

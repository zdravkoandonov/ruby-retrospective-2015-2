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

    def -(other)
      days - other.days
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
        selected_notes = notes.dup
        filter_by_tag(selected_notes, tag) if tag
        filter_by_text(selected_notes, text) if text
        filter_by_status(selected_notes, status) if status
        Agenda.new(selected_notes)
      end

      private

      def filter_by_tag(notes, tag)
        notes.select! { |note| note.tags.include?(tag) }
      end

      def filter_by_text(notes, text)
        notes.select! { |note| note.header[text] || note.body[text] }
      end

      def filter_by_status(notes, status)
        notes.select! { |note| note.status == status }
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
      notes_this_week = dates_this_week.map { |date| daily_agenda(date).notes }
      Agenda.new(notes_this_week.reduce(:+))
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
      dup.with_date!(date_scheduled)
    end

    def with_date!(date_scheduled)
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
      time_between_dates = date - @date
      if @repeat_interval
        time_between_dates >= 0 && time_between_dates % @repeat_interval == 0
      else
        time_between_dates == 0
      end
    end
  end
end

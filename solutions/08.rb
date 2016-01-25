class Spreadsheet
  class Error < RuntimeError
  end

  def initialize(data_string = "")
    @table = data_string.strip.split("\n")
      .map { |row_string| row_string.strip.split(/\t| {2,}/) }
  end

  def empty?
    @table.empty?
  end

  def cell_at(cell_index)
    cell_index.match(/\A(?<column>[[:upper:]]+)(?<row>\d+)\Z/) do |match|
      row, column = match["row"].to_i - 1, column_to_index(match["column"])
      if row > @table.size or column > @table[0].size
        raise Error, "Cell '#{cell_index}' does not exist"
      else
        return @table[row][column]
      end
    end

    raise Error, "Invalid cell index '#{cell_index}'"
  end

  def [](cell_index)
    cell_string = cell_at(cell_index)
    evaluate(cell_string)
  end

  def to_s
    @table.map { |row| row.map { |data| evaluate(data) }.join("\t") }.join("\n")
  end

  private

  def column_to_index(column_string)
    addends = column_string.each_char.map.with_index do |char, index|
      (char.ord - 'A'.ord + 1) * 26**(column_string.size - index - 1)
    end
    addends.reduce(:+) - 1
  end

  def evaluate(cell_string)
    if cell_string[0] == '='
      Expression.new(cell_string[1..-1].lstrip, self).value
    else
      cell_string
    end
  end

  class Functions
    class << self
      def add(arguments)
        if arguments.size >= 2
          arguments.reduce(:+)
        else
          message = "Wrong number of arguments for 'ADD':" +
            " expected at least 2, got #{arguments.size}"
          raise Error, message
        end
      end

      def multiply(arguments)
        if arguments.size >= 2
          arguments.reduce(:*)
        else
          message = "Wrong number of arguments for 'MULTIPLY':" +
            " expected at least 2, got #{arguments.size}"
          raise Error, message
        end
      end

      def subtract(arguments)
        if arguments.size == 2
          arguments[0] - arguments[1]
        else
          message = "Wrong number of arguments for 'SUBTRACT':" +
            " expected 2, got #{arguments.size}"
          raise Error, message
        end
      end

      def divide(arguments)
        if arguments.size == 2
          arguments[0] / arguments[1]
        else
          message = "Wrong number of arguments for 'DIVIDE':" +
            " expected 2, got #{arguments.size}"
          raise Error, message
        end
      end

      def mod(arguments)
        if arguments.size == 2
          arguments[0] % arguments[1]
        else
          message = "Wrong number of arguments for 'MOD':" +
            " expected 2, got #{arguments.size}"
          raise Error, message
        end
      end
    end
  end

  class Expression
    ARGUMENT = /((\d+(\.\d+)?)|([[:upper:]]+\d+))/
    FUNCTION = /[[:upper:]]+\(#{ARGUMENT}(\s*,\s*#{ARGUMENT})*\)/

    attr_accessor :value

    def initialize(expression_string, spreadsheet)
      @expression_string = expression_string
      @spreadsheet = spreadsheet
      result = calculate_expression(expression_string)
      @value = format_number_to_string(result.to_f)
    end

    private

    def calculate_expression(expression)
      if /\A#{ARGUMENT}\Z/ =~ expression
        calculate_argument(expression)
      elsif /\A#{FUNCTION}\Z/ =~ expression
        calculate_valid_function_from_string(expression)
      else
        raise Error, "Invalid expression '#{expression}'"
      end
    end

    def calculate_argument(expression)
      if expression =~ /\A\d/
        expression.to_f
      else
        @spreadsheet[expression]
      end
    end

    def calculate_valid_function_from_string(expression)
      function = /(?<name>[[:upper:]]+)\((?<arguments>.+)\)/.match(expression)
      calculate_function(function[:name], function[:arguments])
    end

    def calculate_function(function_name, arguments_string)
      arguments = arguments_string.split(/\s*,\s*/)
        .map { |argument| calculate_argument(argument).to_f }
      Functions.public_send(function_name.downcase.to_sym, arguments)
    rescue NoMethodError
      raise Error, "Unknown function '#{function_name}'"
    end

    def whole_number?(float)
      float.to_i == float
    end

    def format_number_to_string(float)
      if whole_number?(float)
        float.to_i.to_s
      else
        sprintf("%.2f", float.round(2))
      end
    end
  end
end

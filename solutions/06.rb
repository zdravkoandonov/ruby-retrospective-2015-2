module TurtleGraphics
  class Canvas
    def self.max_steps(canvas)
      canvas.map(&:max).max
    end

    class ASCII
      def initialize(characters)
        @characters = characters
      end

      def build(canvas)
        max_steps = Canvas.max_steps(canvas)
        ascii_rows = canvas.map do |row|
          row_of_characters = row.map do |cell|
            @characters[((@characters.size - 1) * cell.to_f / max_steps).ceil]
          end
          row_of_characters.join
        end
        ascii_rows.join("\n")
      end
    end

    class HTML
      def initialize(cell_size)
        @html_string = <<-HTML.gsub(/^\s{8}/, '')
        <!DOCTYPE html>
        <html>
        <head>
          <title>Turtle graphics</title>

          <style>
            table {
              border-spacing: 0;
            }

            tr {
              padding: 0;
            }

            td {
              width: #{cell_size}px;
              height: #{cell_size}px;

              background-color: black;
              padding: 0;
            }
          </style>
        </head>
        <body>
          <table>
          %{rows}
          </table>
        </body>
        </html>
        HTML
      end

      def build(canvas)
        max_steps = Canvas.max_steps(canvas)
        table_rows = canvas.map do |row|
          table_data = row.map do |cell|
            '<td style="opacity: ' +
              format('%.2f', cell.to_f / max_steps) +
                '"></td>'
          end
          '<tr>' + table_data.join + '</tr>'
        end
        @html_string % {rows: table_rows.join}
      end
    end
  end

  class Turtle
    ORIENTATIONS = {left: [0, -1], up: [-1, 0], right: [0, 1], down: [1, 0]}

    def initialize(rows, columns)
      @rows = rows
      @columns = columns
      @x = 0
      @y = 0
      @direction_x, @direction_y = ORIENTATIONS[:right]
      @canvas = Array.new(rows) { Array.new(columns, 0) }
    end

    def draw(output = nil)
      @canvas[@y][@x] += 1
      self.instance_eval(&Proc.new)
      if (output)
        output.build(@canvas)
      else
        @canvas
      end
    end

    def move
      @x = (@x + @direction_x) % @rows
      @y = (@y + @direction_y) % @columns
      @canvas[@x][@y] += 1
    end

    def turn_left
      @direction_x, @direction_y = [-@direction_y, @direction_x]
    end

    def turn_right
      @direction_x, @direction_y = [@direction_y, - @direction_x]
    end

    def spawn_at(row, column)
      @canvas[@x][@y] -= 1
      @x, @y = row, column
      @canvas[@x][@y] += 1
    end

    def look(orientation)
      @direction_x, @direction_y = ORIENTATIONS[orientation]
    end
  end
end

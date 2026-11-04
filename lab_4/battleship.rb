class GameError < StandardError; end
class InvalidCoordinateError < GameError; end
class RepeatShotError < GameError; end

class Ship
  attr_reader :cells

  def initialize(cells)
    @cells = cells
    @hits = []
  end

  def hit(cell)
    @hits << cell
  end

  def sunk?
    @hits.size == @cells.size
  end
end

class Board
  SIZE = 10
  FLEET = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1]
  LETTERS = %w[A B C D E F G H I J]

  def initialize
    @ships = []
    @shots = {}
    place_ships
  end

  def self.parse(input)
    m = input.to_s.strip.match(/\A([A-J])(10|[1-9])\z/i)
    raise InvalidCoordinateError, "Невірні координати (приклад: B5, літери A-J, числа 1-10)" unless m
    [m[2].to_i - 1, LETTERS.index(m[1].upcase)]
  end

  def self.name(cell)
    "#{LETTERS[cell[1]]}#{cell[0] + 1}"
  end

  def shoot(cell)
    raise RepeatShotError, "Ви вже стріляли в #{Board.name(cell)}" if @shots[cell]
    ship = @ships.find { |s| s.cells.include?(cell) }
    return @shots[cell] = :miss unless ship
    ship.hit(cell)
    @shots[cell] = :hit
    return :hit unless ship.sunk?
    ship.cells.each { |c| around(c).each { |n| @shots[n] ||= :miss } }
    :sunk
  end

  def shot?(cell)
    @shots.key?(cell)
  end

  def free_cells
    all = (0...SIZE).to_a.product((0...SIZE).to_a)
    all.reject { |c| shot?(c) }
  end

  def all_sunk?
    @ships.all?(&:sunk?)
  end

  def lines(reveal)
    rows = ["   " + LETTERS.join(" ")]
    SIZE.times do |r|
      row = (0...SIZE).map do |c|
        case @shots[[r, c]]
        when :hit then "X"
        when :miss then "o"
        else reveal && @ships.any? { |s| s.cells.include?([r, c]) } ? "S" : "."
        end
      end
      rows << format("%2d %s", r + 1, row.join(" "))
    end
    rows
  end

  private

  def around(cell)
    d = [-1, 0, 1]
    d.product(d).map { |a, b| [cell[0] + a, cell[1] + b] }.select { |r, c| r.between?(0, 9) && c.between?(0, 9) }
  end

  def place_ships
    FLEET.each do |len|
      loop do
        horizontal = rand < 0.5
        r = rand(horizontal ? SIZE : SIZE - len + 1)
        c = rand(horizontal ? SIZE - len + 1 : SIZE)
        cells = Array.new(len) { |i| horizontal ? [r, c + i] : [r + i, c] }
        busy = @ships.flat_map(&:cells)
        next if cells.any? { |cell| around(cell).any? { |n| busy.include?(n) } }
        @ships << Ship.new(cells)
        break
      end
    end
  end
end

class Computer
  def initialize
    @queue = []
  end

  def choose(board)
    @queue.shift while @queue.any? && board.shot?(@queue.first)
    @queue.shift || board.free_cells.sample
  end

  def result(cell, res)
    @queue.clear if res == :sunk
    return unless res == :hit
    [[-1, 0], [1, 0], [0, -1], [0, 1]].each do |a, b|
      n = [cell[0] + a, cell[1] + b]
      @queue << n if n.all? { |v| v.between?(0, 9) }
    end
  end
end

class Game
  TEXT = { miss: "Промах.", hit: "Влучання!", sunk: "Корабель знищено!" }

  def play
    mine = Board.new
    theirs = Board.new
    ai = Computer.new
    turn = :player

    loop do
      puts "\n#{'Ваше поле'.ljust(25)}   Поле комп'ютера"
      mine.lines(true).zip(theirs.lines(false)) { |a, b| puts "#{a.ljust(25)}   #{b}" }

      if turn == :player
        shot = ask(theirs)
        return :quit unless shot
        cell, res = shot
        puts "Ви: #{Board.name(cell)} - #{TEXT[res]}"
        return :win if theirs.all_sunk?
        turn = :computer if res == :miss
      else
        cell = ai.choose(mine)
        res = mine.shoot(cell)
        ai.result(cell, res)
        puts "Комп'ютер: #{Board.name(cell)} - #{TEXT[res]}"
        return :loss if mine.all_sunk?
        turn = :player if res == :miss
      end
    end
  end

  private

  def ask(board)
    loop do
      print "Постріл (q - вихід): "
      line = gets
      return nil if line.nil? || line.strip.downcase == "q"
      begin
        cell = Board.parse(line)
        return [cell, board.shoot(cell)]
      rescue GameError => e
        puts "Помилка: #{e.message}"
      end
    end
  end
end

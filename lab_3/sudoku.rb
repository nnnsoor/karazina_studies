LEVELS = {
  "1" => [
    [1, 0, 3, 4],
    [3, 4, 0, 2],
    [0, 1, 4, 3],
    [4, 3, 2, 0]
  ],
  "2" => [
    [1, 2, 0, 4],
    [0, 4, 1, 0],
    [0, 1, 4, 0],
    [4, 0, 0, 1]
  ],
  "3" => [
    [1, 2, 0, 0],
    [0, 4, 1, 0],
    [0, 0, 4, 0],
    [4, 0, 0, 1]
  ]
}

def choose_level
  loop do
    puts "Оберіть рівень: 1 - легкий, 2 - середній, 3 - складний"
    print "Рівень: "
    line = $stdin.gets
    return nil if line.nil?
    key = line.strip
    return LEVELS[key] if LEVELS.key?(key)
    puts "Помилка: введіть 1, 2 або 3."
  end
end

def show(board)
  puts
  puts "  1 2 3 4"
  board.each_with_index do |row, i|
    puts "#{i + 1} " + row.map { |v| v == 0 ? "." : v }.join(" ")
  end
  puts
end

def show_stats(moves, errors)
  puts "Ходів: #{moves}, помилок: #{errors}"
end

def parse(line)
  parts = line.split
  return nil unless parts.size == 3 && parts.all? { |p| p.match?(/\A[1-4]\z/) }
  parts.map(&:to_i)
end

def conflict?(board, r, c, n)
  in_line = 4.times.any? do |i|
    (i != c && board[r][i] == n) || (i != r && board[i][c] == n)
  end
  return true if in_line
  br = r / 2 * 2
  bc = c / 2 * 2
  (br...br + 2).any? do |i|
    (bc...bc + 2).any? { |j| (i != r || j != c) && board[i][j] == n }
  end
end

def won?(board)
  board.all? { |row| row.all? { |v| v != 0 } }
end

def hint(board)
  4.times do |r|
    4.times do |c|
      next unless board[r][c] == 0
      options = (1..4).reject { |n| conflict?(board, r, c, n) }
      return [r, c, options[0]] if options.size == 1
    end
  end
  nil
end

def undo(board, history)
  return false if history.empty?
  r, c, prev = history.pop
  board[r][c] = prev
  true
end

level = choose_level
exit if level.nil?

board = level.map(&:dup)
fixed = level.map { |row| row.map { |v| v != 0 } }
history = []
moves = 0
errors = 0

puts "Судоку 4x4"
puts "Хід: рядок стовпець число (наприклад: 1 3 3)."
puts "Команди: u - скасувати хід, h - підказка, q - вийти."

loop do
  show(board)
  show_stats(moves, errors)
  print "Хід: "
  line = $stdin.gets
  command = line.nil? ? "q" : line.strip.downcase

  if command == "q"
    puts "Гру завершено достроково."
    show_stats(moves, errors)
    break
  end

  if command == "u"
    if undo(board, history)
      puts "Останній хід скасовано."
    else
      puts "Немає ходів для скасування."
    end
    next
  end

  if command == "h"
    tip = hint(board)
    if tip
      puts "Підказка: рядок #{tip[0] + 1}, стовпець #{tip[1] + 1}, число #{tip[2]}."
    else
      puts "Однозначної підказки зараз немає."
    end
    next
  end

  move = parse(command)
  if move.nil?
    errors += 1
    puts "Помилка: потрібно ввести три числа від 1 до 4 через пробіл."
    next
  end

  r, c, n = move
  r -= 1
  c -= 1

  if fixed[r][c]
    errors += 1
    puts "Помилка: початкові числа змінювати заборонено."
    next
  end

  if conflict?(board, r, c, n)
    errors += 1
    puts "Помилка: число #{n} порушує правила (рядок, стовпець або блок 2x2)."
    next
  end

  history.push([r, c, board[r][c]])
  board[r][c] = n
  moves += 1

  if won?(board)
    show(board)
    puts "Перемога! Поле заповнено правильно."
    show_stats(moves, errors)
    break
  end
end

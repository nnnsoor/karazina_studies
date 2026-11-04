require_relative "battleship"

RULES = <<~T
  Поле 10x10. Кораблі: 1x4, 2x3, 3x2, 4x1. Кораблі не торкаються (навіть по діагоналі).
  Вводьте координати, наприклад B5. Влучання дає ще один постріл.
  Перемагає той, хто першим знищить усі кораблі суперника.
T

wins = 0
losses = 0

loop do
  puts "\n1. Нова гра\n2. Правила\n3. Вихід\nПеремоги: #{wins}, поразки: #{losses}"
  print "> "
  choice = gets
  break if choice.nil?

  case choice.strip
  when "1"
    result = Game.new.play
    if result == :win
      wins += 1
      puts "Ви перемогли!"
    elsif result == :loss
      losses += 1
      puts "Ви програли."
    end
  when "2" then puts RULES
  when "3" then break
  else puts "Помилка: оберіть 1, 2 або 3"
  end
end

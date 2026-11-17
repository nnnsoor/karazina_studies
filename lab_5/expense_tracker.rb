require "json"
require "date"

CATEGORIES = %w[food transport study entertainment other].freeze
DATA_FILE = "expenses.json".freeze
DATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

def parse_date(text)
  return nil unless text.to_s.match?(DATE_FORMAT)

  year, month, day = text.split("-").map(&:to_i)
  Date.valid_date?(year, month, day) ? Date.new(year, month, day) : nil
end

def money(kopecks)
  format("%d.%02d", kopecks / 100, kopecks % 100)
end

def validate_record(rec, id_required)
  return "запис не є об'єктом" unless rec.is_a?(Hash)

  if id_required || rec.key?("id")
    id = rec["id"]
    return "id має бути додатним цілим числом" unless id.is_a?(Integer) && id.positive?
  end

  return "дата має бути реальною датою у форматі YYYY-MM-DD" unless rec["date"].is_a?(String) && parse_date(rec["date"])

  amount = rec["amount_in_kopecks"]
  return "amount_in_kopecks має бути додатним цілим числом" unless amount.is_a?(Integer) && amount.positive?

  return "category має бути однією з: #{CATEGORIES.join(', ')}" unless CATEGORIES.include?(rec["category"])

  description = rec["description"]
  return "description має бути рядком" unless description.is_a?(String)

  stripped = description.strip
  return "description не може бути порожнім" if stripped.empty?
  return "description не може перевищувати 200 символів" if stripped.length > 200

  nil
end

def normalize_record(rec, id)
  {
    "id" => id,
    "date" => rec["date"],
    "amount_in_kopecks" => rec["amount_in_kopecks"],
    "category" => rec["category"],
    "description" => rec["description"].strip
  }
end

def load_expenses
  return [] unless File.exist?(DATA_FILE)

  content = File.read(DATA_FILE, encoding: "UTF-8")
  if content.strip.empty?
    puts "Помилка: файл #{DATA_FILE} порожній. Файл не змінено."
    return nil
  end

  data = JSON.parse(content)
  unless data.is_a?(Array)
    puts "Помилка: файл #{DATA_FILE} має містити список записів. Файл не змінено."
    return nil
  end

  records = []
  seen = {}
  data.each_with_index do |rec, index|
    error = validate_record(rec, true)
    if error.nil? && seen[rec["id"]]
      error = "id #{rec['id']} повторюється"
    end
    if error
      puts "Помилка у записі №#{index + 1} файлу #{DATA_FILE}: #{error}. Файл не змінено."
      return nil
    end
    seen[rec["id"]] = true
    records << normalize_record(rec, rec["id"])
  end
  records
rescue JSON::ParserError, EncodingError
  puts "Помилка: файл #{DATA_FILE} пошкоджений. Файл не змінено."
  nil
rescue SystemCallError, IOError
  puts "Помилка: не вдалося прочитати файл #{DATA_FILE}. Файл не змінено."
  nil
end

def save_expenses(expenses)
  temp = "#{DATA_FILE}.tmp"
  File.write(temp, JSON.pretty_generate(expenses), encoding: "UTF-8")
  File.rename(temp, DATA_FILE)
  true
rescue SystemCallError, IOError
  File.delete(temp) rescue nil
  false
end

def commit(state, new_list)
  if save_expenses(new_list)
    state[:expenses] = new_list
    true
  else
    puts "Помилка: не вдалося зберегти зміни. Дані залишено без змін."
    false
  end
end

def ask(text)
  print text
  line = $stdin.gets
  if line.nil?
    puts
    exit 0
  end
  line.strip
end

def sorted(list)
  list.sort_by { |e| [e["date"], e["id"]] }
end

def print_table(list)
  puts format("%-6s %-12s %14s  %-15s %s", "ID", "Дата", "Сума, грн", "Категорія", "Опис")
  sorted(list).each do |e|
    puts format("%-6d %-12s %14s  %-15s %s", e["id"], e["date"], money(e["amount_in_kopecks"]), e["category"], e["description"])
  end
end

def total(list)
  list.sum { |e| e["amount_in_kopecks"] }
end

def read_date(label, optional)
  text = ask(label)
  return [true, nil] if optional && text.empty?

  date = parse_date(text)
  if date.nil?
    puts "Некоректна дата. Введіть реальну дату у форматі YYYY-MM-DD."
    return [false, nil]
  end
  [true, date]
end

def read_period(optional)
  hint = optional ? ", Enter — без обмеження" : ""
  ok, from = read_date("Початкова дата (YYYY-MM-DD#{hint}): ", optional)
  return nil unless ok

  ok, to = read_date("Кінцева дата (YYYY-MM-DD#{hint}): ", optional)
  return nil unless ok

  if from && to && from > to
    puts "Початкова дата не може бути пізнішою за кінцеву."
    return nil
  end
  [from, to]
end

def in_period?(expense, from, to)
  date = parse_date(expense["date"])
  (from.nil? || date >= from) && (to.nil? || date <= to)
end

def next_id(list)
  list.empty? ? 1 : list.map { |e| e["id"] }.max + 1
end

def add_expense(state)
  date_text = ask("Дата (YYYY-MM-DD): ")
  if parse_date(date_text).nil?
    puts "Некоректна дата. Введіть реальну дату у форматі YYYY-MM-DD."
    return
  end

  amount_text = ask("Сума в копійках (ціле додатне число): ")
  unless amount_text.match?(/\A\d+\z/) && amount_text.to_i.positive?
    puts "Некоректна сума. Введіть додатне ціле число копійок."
    return
  end

  category = ask("Категорія (#{CATEGORIES.join(', ')}): ")
  unless CATEGORIES.include?(category)
    puts "Некоректна категорія. Доступні: #{CATEGORIES.join(', ')}."
    return
  end

  description = ask("Опис (до 200 символів): ")
  if description.empty?
    puts "Опис не може бути порожнім."
    return
  end
  if description.length > 200
    puts "Опис не може перевищувати 200 символів."
    return
  end

  record = {
    "id" => next_id(state[:expenses]),
    "date" => date_text,
    "amount_in_kopecks" => amount_text.to_i,
    "category" => category,
    "description" => description
  }
  puts "Витрату додано. ID: #{record['id']}." if commit(state, state[:expenses] + [record])
end

def view_all(state)
  if state[:expenses].empty?
    puts "Список витрат порожній."
    return
  end
  print_table(state[:expenses])
end

def filter_expenses(state)
  category = ask("Категорія (#{CATEGORIES.join(', ')}, Enter — усі): ")
  unless category.empty? || CATEGORIES.include?(category)
    puts "Некоректна категорія. Доступні: #{CATEGORIES.join(', ')}."
    return
  end

  period = read_period(true)
  return unless period

  from, to = period
  result = state[:expenses].select do |e|
    (category.empty? || e["category"] == category) && in_period?(e, from, to)
  end

  if result.empty?
    puts "Витрат за вказаними умовами не знайдено."
    puts "Сума: 0.00 грн"
    return
  end

  print_table(result)
  puts "Сума: #{money(total(result))} грн"
end

def delete_expense(state)
  id_text = ask("ID витрати для видалення: ")
  unless id_text.match?(/\A\d+\z/) && id_text.to_i.positive?
    puts "Некоректний ідентифікатор. Введіть додатне ціле число."
    return
  end

  id = id_text.to_i
  target = state[:expenses].find { |e| e["id"] == id }
  if target.nil?
    puts "Витрату з ID #{id} не знайдено."
    return
  end

  print_table([target])
  answer = ask("Підтвердити видалення? (y/n): ").downcase
  if %w[y yes так т].include?(answer)
    puts "Витрату видалено." if commit(state, state[:expenses].reject { |e| e["id"] == id })
  elsif %w[n no ні н].include?(answer)
    puts "Видалення скасовано."
  else
    puts "Некоректна відповідь. Видалення скасовано."
  end
end

def show_total(state)
  puts "Загальна сума витрат: #{money(total(state[:expenses]))} грн"
end

def show_by_category(state)
  CATEGORIES.each do |category|
    sum = total(state[:expenses].select { |e| e["category"] == category })
    puts format("%-15s %s грн", category, money(sum))
  end
end

def show_largest(state)
  if state[:expenses].empty?
    puts "Список витрат порожній."
    return
  end

  max = state[:expenses].map { |e| e["amount_in_kopecks"] }.max
  print_table(state[:expenses].select { |e| e["amount_in_kopecks"] == max })
end

def show_period_sum(state)
  period = read_period(false)
  return unless period

  from, to = period
  result = state[:expenses].select { |e| in_period?(e, from, to) }
  if result.empty?
    puts "За вказаний період витрат не знайдено."
    puts "Сума: 0.00 грн"
    return
  end

  puts "Сума за період з #{from} по #{to}: #{money(total(result))} грн"
end

def statistics_menu(state)
  loop do
    puts
    puts "--- Статистика ---"
    puts "1. Загальна сума"
    puts "2. Суми за категоріями"
    puts "3. Найбільша витрата"
    puts "4. Сума за період"
    puts "0. Назад"
    case ask("Оберіть дію: ")
    when "1" then show_total(state)
    when "2" then show_by_category(state)
    when "3" then show_largest(state)
    when "4" then show_period_sum(state)
    when "0" then return
    else puts "Невідома команда. Введіть число від 0 до 4."
    end
  end
end

def import_expenses(state)
  path = ask("Шлях до JSON-файла: ")
  if path.empty?
    puts "Шлях не може бути порожнім."
    return
  end

  unless File.file?(path)
    puts "Файл не знайдено: #{path}"
    return
  end

  data = JSON.parse(File.read(path, encoding: "UTF-8"))
  unless data.is_a?(Array)
    puts "Помилка: файл має містити список витрат. Імпорт скасовано."
    return
  end

  if data.empty?
    puts "Файл не містить витрат. Нічого імпортувати."
    return
  end

  id = next_id(state[:expenses])
  imported = []
  data.each_with_index do |rec, index|
    error = validate_record(rec, false)
    if error
      puts "Помилка у записі №#{index + 1}: #{error}. Імпорт скасовано, наявні записи не змінено."
      return
    end
    imported << normalize_record(rec, id)
    id += 1
  end

  puts "Імпортовано витрат: #{imported.length}." if commit(state, state[:expenses] + imported)
rescue JSON::ParserError, EncodingError
  puts "Помилка: файл має некоректний формат JSON. Імпорт скасовано."
rescue SystemCallError, IOError
  puts "Помилка: не вдалося прочитати файл. Імпорт скасовано."
end

def main
  expenses = load_expenses
  exit 1 if expenses.nil?

  state = { expenses: expenses }

  loop do
    puts
    puts "=== ExpenseTracker ==="
    puts "1. Додати витрату"
    puts "2. Переглянути всі витрати"
    puts "3. Фільтрувати за категорією та періодом"
    puts "4. Видалити витрату"
    puts "5. Статистика"
    puts "6. Імпортувати з JSON-файла"
    puts "0. Вийти"
    case ask("Оберіть дію: ")
    when "1" then add_expense(state)
    when "2" then view_all(state)
    when "3" then filter_expenses(state)
    when "4" then delete_expense(state)
    when "5" then statistics_menu(state)
    when "6" then import_expenses(state)
    when "0"
      puts "До побачення!"
      break
    else
      puts "Невідома команда. Введіть число від 0 до 6."
    end
  end
end

main

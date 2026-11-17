require "csv"

DATA_FILE = "students.csv".freeze
REPORT_FILE = "report.txt".freeze
HEADERS = %w[name subject grade].freeze

def parse_grade(text)
  value = text.to_s.strip
  return nil unless value.match?(/\A\d{1,3}\z/)

  grade = value.to_i
  grade.between?(0, 100) ? grade : nil
end

def build_record(name, subject, grade_text)
  return [nil, "ім'я не може бути порожнім"] if name.nil? || name.strip.empty?
  return [nil, "предмет не може бути порожнім"] if subject.nil? || subject.strip.empty?

  grade = parse_grade(grade_text)
  return [nil, "оцінка має бути цілим числом від 0 до 100"] if grade.nil?

  [{ name: name.strip, subject: subject.strip, grade: grade }, nil]
end

def load_records
  unless File.exist?(DATA_FILE)
    puts "Файл #{DATA_FILE} не знайдено. Роботу розпочато з порожнім списком, файл буде створено після першого збереження."
    return []
  end

  content = File.read(DATA_FILE, encoding: "bom|utf-8")
  if content.strip.empty?
    puts "Файл #{DATA_FILE} порожній. Роботу розпочато з порожнім списком."
    return []
  end

  table = CSV.parse(content, headers: true, skip_blanks: true)
  headers = table.headers.map { |h| h.to_s.strip }
  unless headers == HEADERS
    puts "Помилка: заголовок файлу #{DATA_FILE} має бути: #{HEADERS.join(',')}. Файл не змінено."
    return nil
  end

  records = []
  table.each_with_index do |row, index|
    line = index + 2
    fields = row.fields
    unless fields.length == 3
      puts "Помилка у рядку #{line}: очікується 3 поля. Файл не змінено."
      return nil
    end

    record, error = build_record(*fields)
    if error
      puts "Помилка у рядку #{line}: #{error}. Файл не змінено."
      return nil
    end
    records << record
  end

  puts "Файл #{DATA_FILE} не містить записів." if records.empty?
  records
rescue CSV::MalformedCSVError, EncodingError, ArgumentError
  puts "Помилка: файл #{DATA_FILE} має некоректний формат CSV. Файл не змінено."
  nil
rescue SystemCallError, IOError
  puts "Помилка: не вдалося прочитати файл #{DATA_FILE}."
  nil
end

def save_records(records)
  temp = "#{DATA_FILE}.tmp"
  CSV.open(temp, "w", encoding: "UTF-8") do |csv|
    csv << HEADERS
    records.each { |r| csv << [r[:name], r[:subject], r[:grade]] }
  end
  File.rename(temp, DATA_FILE)
  true
rescue SystemCallError, IOError
  begin
    File.delete(temp) if File.exist?(temp)
  rescue SystemCallError
    nil
  end
  false
end

def commit(state, new_records)
  if save_records(new_records)
    state[:records] = new_records
    true
  else
    puts "Помилка: не вдалося зберегти зміни у #{DATA_FILE}. Дані залишено без змін."
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

def average(grades)
  Rational(grades.sum, grades.length)
end

def averages_by(records, key)
  records.group_by { |r| r[key].downcase }
         .map { |_, group| [group.first[key], average(group.map { |r| r[:grade] })] }
         .sort_by { |name, _| name.downcase }
end

def extremes(averages)
  highest = averages.map(&:last).max
  lowest = averages.map(&:last).min
  [averages.select { |_, avg| avg == highest }, averages.select { |_, avg| avg == lowest }]
end

def format_averages(averages)
  averages.map { |name, avg| format("%-20s %6.2f", name, avg) }
end

def print_records(records)
  puts format("%-4s %-20s %-15s %s", "№", "Ім'я", "Предмет", "Оцінка")
  records.each_with_index do |r, i|
    puts format("%-4d %-20s %-15s %d", i + 1, r[:name], r[:subject], r[:grade])
  end
end

def list_all(state)
  if state[:records].empty?
    puts "Список порожній."
    return
  end
  print_records(state[:records])
end

def show_student_averages(state)
  if state[:records].empty?
    puts "Немає даних для розрахунку."
    return
  end
  puts format("%-20s %s", "Студент", "Середній бал")
  puts format_averages(averages_by(state[:records], :name))
end

def show_extremes(state)
  if state[:records].empty?
    puts "Немає даних для розрахунку."
    return
  end

  highest, lowest = extremes(averages_by(state[:records], :name))
  puts "Найвищий середній бал:"
  puts format_averages(highest)
  puts "Найнижчий середній бал:"
  puts format_averages(lowest)
end

def show_subject_averages(state)
  if state[:records].empty?
    puts "Немає даних для розрахунку."
    return
  end
  puts format("%-20s %s", "Предмет", "Середній бал")
  puts format_averages(averages_by(state[:records], :subject))
end

def search_student(state)
  query = ask("Ім'я студента (або його частина): ")
  if query.empty?
    puts "Ім'я для пошуку не може бути порожнім."
    return
  end

  found = state[:records].select { |r| r[:name].downcase.include?(query.downcase) }
  if found.empty?
    puts "Студентів за запитом \"#{query}\" не знайдено."
    return
  end

  found.group_by { |r| r[:name].downcase }.each_value do |group|
    puts
    puts "Студент: #{group.first[:name]}"
    group.each { |r| puts format("  %-15s %d", r[:subject], r[:grade]) }
    puts format("  Середній бал: %.2f", average(group.map { |r| r[:grade] }))
  end
end

def read_grade_data(default)
  name_hint = default ? " (Enter — залишити \"#{default[:name]}\")" : ""
  subject_hint = default ? " (Enter — залишити \"#{default[:subject]}\")" : ""
  grade_hint = default ? " (Enter — залишити #{default[:grade]})" : ""

  name = ask("Ім'я#{name_hint}: ")
  name = default[:name] if default && name.empty?
  subject = ask("Предмет#{subject_hint}: ")
  subject = default[:subject] if default && subject.empty?
  grade = ask("Оцінка 0-100#{grade_hint}: ")
  grade = default[:grade].to_s if default && grade.empty?

  build_record(name, subject, grade)
end

def add_grade(state)
  record, error = read_grade_data(nil)
  if error
    puts "Помилка: #{error}."
    return
  end

  puts "Оцінку додано." if commit(state, state[:records] + [record])
end

def read_record_number(state)
  if state[:records].empty?
    puts "Список порожній."
    return nil
  end

  print_records(state[:records])
  text = ask("Номер запису: ")
  unless text.match?(/\A\d+\z/) && text.to_i.between?(1, state[:records].length)
    puts "Некоректний номер. Введіть число від 1 до #{state[:records].length}."
    return nil
  end
  text.to_i - 1
end

def edit_grade(state)
  index = read_record_number(state)
  return if index.nil?

  record, error = read_grade_data(state[:records][index])
  if error
    puts "Помилка: #{error}."
    return
  end

  updated = state[:records].dup
  updated[index] = record
  puts "Запис змінено." if commit(state, updated)
end

def delete_grade(state)
  index = read_record_number(state)
  return if index.nil?

  answer = ask("Підтвердити видалення? (y/n): ").downcase
  if %w[y yes так т].include?(answer)
    updated = state[:records].dup
    updated.delete_at(index)
    puts "Запис видалено." if commit(state, updated)
  elsif %w[n no ні н].include?(answer)
    puts "Видалення скасовано."
  else
    puts "Некоректна відповідь. Видалення скасовано."
  end
end

def build_report(records)
  lines = ["Статистичний звіт", "Дата формування: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}", ""]

  if records.empty?
    lines << "Дані відсутні."
    return lines.join("\n") + "\n"
  end

  student_averages = averages_by(records, :name)
  highest, lowest = extremes(student_averages)

  lines << "Кількість записів: #{records.length}"
  lines << "Кількість студентів: #{student_averages.length}"
  lines << "Кількість предметів: #{averages_by(records, :subject).length}"
  lines << ""
  lines << "Середній бал студентів:"
  lines.concat(format_averages(student_averages))
  lines << ""
  lines << "Найвищий середній бал:"
  lines.concat(format_averages(highest))
  lines << ""
  lines << "Найнижчий середній бал:"
  lines.concat(format_averages(lowest))
  lines << ""
  lines << "Середній бал за предметами:"
  lines.concat(format_averages(averages_by(records, :subject)))
  lines.join("\n") + "\n"
end

def save_report(state)
  File.write(REPORT_FILE, build_report(state[:records]), encoding: "UTF-8")
  puts "Звіт збережено у файл #{REPORT_FILE}."
rescue SystemCallError, IOError
  puts "Помилка: не вдалося записати файл #{REPORT_FILE}."
end

def main
  records = load_records
  exit 1 if records.nil?

  state = { records: records }

  loop do
    puts
    puts "=== Аналіз успішності студентів ==="
    puts "1. Усі студенти та оцінки"
    puts "2. Середній бал кожного студента"
    puts "3. Найвищий і найнижчий середній бал"
    puts "4. Середній бал за предметами"
    puts "5. Пошук студента за іменем"
    puts "6. Додати оцінку"
    puts "7. Редагувати оцінку"
    puts "8. Видалити оцінку"
    puts "9. Зберегти звіт у #{REPORT_FILE}"
    puts "0. Вийти"
    case ask("Оберіть дію: ")
    when "1" then list_all(state)
    when "2" then show_student_averages(state)
    when "3" then show_extremes(state)
    when "4" then show_subject_averages(state)
    when "5" then search_student(state)
    when "6" then add_grade(state)
    when "7" then edit_grade(state)
    when "8" then delete_grade(state)
    when "9" then save_report(state)
    when "0"
      puts "До побачення!"
      break
    else
      puts "Невідома команда. Введіть число від 0 до 9."
    end
  end
end

main

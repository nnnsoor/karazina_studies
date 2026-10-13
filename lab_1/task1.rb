def word_stats(text)
  word_count = text.split.size
  longest_word = text.split.max_by(&:length)
  unique_word_count = text.split.to_set.size

  puts "Word count: #{word_count}"
  puts "Longest word: #{longest_word}"
  puts "Unique word count: #{unique_word_count}"
end

word_stats(gets)

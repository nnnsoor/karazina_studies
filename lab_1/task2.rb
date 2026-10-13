def play_game()
  random_number = rand(1..100)
  guesses = 0

  while true
    puts "Guess the number (between 1 and 100):"
    user_guess = gets.chomp.to_i
    guesses += 1

    if user_guess < random_number
      puts 'Higher'
    elsif user_guess > random_number
      puts 'Lower'
    else
      puts "Congratulations! You've guessed the number #{random_number} in #{guesses} attempts."
    break
    end
  end
end

play_game()

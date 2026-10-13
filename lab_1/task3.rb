def play_game()
  user_wins = 0
  computer_wins = 0
  draws = 0
  total_rounds = 0

  while true
    random_choice = ["Rock", "Paper", "Scissors"]
    computer_choice = random_choice.sample

    puts "Pick your move (Rock, Paper, Scissors) or end the game write (1):"
    user_choice = gets.chomp.capitalize

    total_rounds += 1

    if user_choice == "1"
      puts "Goodbye!"
      break
    end

    if user_choice == computer_choice
      puts 'Draw'
      draws += 1

    elsif user_choice == "Rock" && computer_choice == "Paper"
      puts 'Computer wins!'
      computer_wins += 1

    elsif user_choice == "Rock" && computer_choice == "Scissors"
      puts 'You win!'
      user_wins += 1

    elsif user_choice == "Paper" && computer_choice == "Rock"
      puts 'You win!'
      user_wins += 1

    elsif user_choice == "Paper" && computer_choice == "Scissors"
      puts 'Computer wins!'
      computer_wins += 1

    elsif user_choice == "Scissors" && computer_choice == "Rock"
      puts 'Computer wins!'
      computer_wins += 1

    elsif user_choice == "Scissors" && computer_choice == "Paper"
      puts 'You win!'
      user_wins += 1

    else
      puts "Invalid choice. Please choose Rock, Paper, or Scissors."
      total_rounds -= 1
      next
    end
  end

  puts "Total rounds: #{total_rounds}, total wins: #{user_wins}, total losses: #{computer_wins}, total draws: #{draws}"
end
play_game()

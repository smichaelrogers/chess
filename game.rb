require_relative 'board'
require_relative 'library'
require 'rainbow'
require 'rainbow/ext/string'

class Game
  attr_reader :board, :player
  def initialize(board = Board.new, player = "Player")
    @player = player
    @board = board
  end

  def self.new_game
    puts " ══════════════════════════════════"
    sleep 0.2
    puts  "   ♔ Computer Player (white)"
    print "   ♚ ...? "
    name = gets.chomp
    sleep 0.2
    puts " ══════════════════════════════════"
    puts "   ♔ Computer Player (white)"
    puts "   ♚ #{name} (black)"
    puts " ══════════════════════════════════"
    puts
    puts " Print evaluation data? (y/n)"
    while true
      yn = gets.chomp.downcase
      break if yn == "y" || yn == "n"
      puts "(y/n)"
    end
    b = Board.new
    b.display_data if yn == "y"
    game = Game.new(b, name)
    game.play
  end

  def play
    won, winner, valid_entry = false, nil, false
    second_pos, second_entry = [], ""
    until won
      puts board.render(false)
      board.white_move!
      game_over(:white) if board.checkmate?(:black)
      puts board.render(false)
      while true
        black_piece_position = get_first_position
        puts board.render(true, black_piece_position)
        puts
        puts "Move #{board[black_piece_position].render} to...  ('u' to reselect)"
        second_entry = gets.chomp
        if second_entry.include?("u")
          puts board.render(false)
          next
        end
        second_pos = validate_entry(second_entry, black_piece_position, true)
        if second_pos.nil?
          puts "let's try that again"
          next
        else
          board.black_move(black_piece_position, second_pos)
          puts " ══════════════════════════════════"
          puts "   ♔ Computer Player's turn"
          puts " ══════════════════════════════════"
          break
        end
      end
    end
  end


  def get_first_position
    entry, pos = "", []
    puts " ══════════════════════════════════"
    puts "   ♚ #{player}'s turn"
    puts " ══════════════════════════════════"
    while true
      puts "Select column and row - i.e. 'e2', 'b1', etc."
      print "Piece position: "
      entry = gets.chomp
      pos = validate_entry(entry)
      if pos.nil?
        puts "That work work..."
      else
        return pos
      end
    end
    nil
  end

  def validate_entry(entry, origin = nil, moving = false)
    return nil unless entry.length > 1
    files, ranks = "abcdefgh", "12345678"
    pos, row, col = [], 0, 0
    if files.include?(entry[0].downcase) && ranks.include?(entry[1])
      row = ranks.index(entry[1])
      col = files.index(entry[0].downcase)
      pos = [row, col]
      unless moving
        return nil if @board.empty?(pos)
        return nil unless @board[pos].color == :black
        unless @board[pos].valid_moves.empty?
          return pos
        end
      else
        if @board[origin].valid_moves.include?(pos)
          return pos
        end
      end
    end
    nil
  end


  def game_over(color)
    s = "\n" * 5
    s += color.to_s + "   Wins"
    s += "\n" * 5
  end



  def get_second_coordinate
    puts
    print "Move piece".underline
    puts
    print " ← →  ↑ ↓ Column: "
    to_col = gets.chomp.to_i

    [to_row, to_col]
  end
end

Game.new_game

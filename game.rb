require_relative 'board'
require_relative 'library'
require 'rainbow'
require 'rainbow/ext/string'

class Game
  attr_reader :board
  def initialize
    @board = Board.new
  end

  def play
    while true
      puts board.render(false)
      board.white_move!
      board.turns = board.turns + 1
      if board.checkmate?(:black)
        Game.game_over(:white)
        break
      end
      while true
        puts board.render(false)
        first_coord = get_first_coordinate
        unless board.empty?(first_coord)
          break if board[first_coord].valid_moves && board[first_coord].color == :black
        else
          next
        end
      end
      while true
        puts board.render(true, first_coord)
        move = get_second_coordinate
        break if board.black_move([first_coord[0], first_coord[1]],[move[0], move[1]])
      end
      if board.checkmate?(:white)
        puts Game.game_over(:black)
        break
      end
    end
  end

  def self.game_over(color)
    s = "\n" * 5
    s += color.to_s + "   Wins"
    s += "\n" * 5
  end

  def get_first_coordinate
    print "Select piece".underline
    puts
    print " ← → Row: "
    from_row = gets.chomp.to_i
    print " ↑ ↓ Column: "
    from_col = gets.chomp.to_i

    [from_row, from_col]
  end


  def get_second_coordinate
    puts
    print "Move piece".underline
    puts
    print " ← → Row: "
    to_row = gets.chomp.to_i
    print " ↑ ↓ Column: "
    to_col = gets.chomp.to_i

    [to_row, to_col]
  end
end

game = Game.new
game.play

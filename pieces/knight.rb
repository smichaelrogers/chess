require_relative 'piece'
require_relative 'stepable'

class Knight < Piece
  attr_reader :move_diffs
  include Stepable

  def move_diffs
    [[-2, -1],
     [-1, -2],
     [-2, 1],
     [-1, 2],
     [1, -2],
     [2, -1],
     [1, 2],
     [2, 1]]
  end
end

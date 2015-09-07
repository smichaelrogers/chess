require_relative 'piece'
require_relative 'stepable'

class King < Piece
  include Stepable

  def adjacent_tiles
    move_diffs.map do |diff|
      [diff[0] + pos[0], diff[1] + pos[1]]
    end.select do |m|
      m < 8 && m >= 0
    end
  end


  def move_diffs
    [[-1, -1],
     [-1, 0],
     [-1, 1],
     [0, -1],
     [0, 1],
     [1, -1],
     [1, 0],
     [1, 1]]
  end
end

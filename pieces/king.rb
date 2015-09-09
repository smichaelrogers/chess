require_relative 'piece'
require_relative 'stepable'

class King < Piece
  include Stepable

  def adjacent_tiles
    t = []
    move_diffs.each do |diff|
      if pos[0] + diff[0] >= 0 && pos[0] + diff[0] <= 7 && pos[1] + diff[1] >= 0 && pos[1] + diff[1] <= 7
        t << [pos[0] + diff[0], pos[1] + diff[1]]
      end
    end
    t
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

class Piece
    attr_reader :board,
                :color,
                :class_sym
  attr_accessor :pos,
                :value,
                :pid

  def initialize(color, board, pos, pid)
    @pid = pid
    @class_sym = self.class.to_s.to_sym
    @value = MATERIAL[class_sym]
    @color, @board, @pos = color, board, pos
    board.add_piece(self, pos)
  end

  def line_key
    pk = ["a","b","c","d","e","f","g","h"][pos[0]] + (pos[1] + 1).to_s
    tk = (class_sym == :Knight ? "n" : self.class.to_s[0].downcase)
    "#{color.to_s[0]}_#{tk}_#{pk}"
  end

  def forward_dir
    (color == :white) ? -1 : 1
  end

  def render
    SYMBOLS[class_sym][color]
  end

  def mv
    pv = (color == :white ? SQUARES[class_sym][pos[0]][pos[1]] : SQUARES[class_sym][7 - pos[0]][pos[1]])
    pv + MATERIAL[class_sym] + moves.count
  end

  def symbols
    raise NotImplementedError
  end

  def valid_moves
    moves.reject { |to_pos| move_into_check?(to_pos) }
  end

  private

  def move_into_check?(to_pos)
    target = nil
    original_pos = pos
    if board[to_pos]
      target = board[to_pos]
    end
    board.move_piece!(pos, to_pos)
    result = board.in_check?(color)
    board.undo!(to_pos, original_pos)
    if target
      board[to_pos] = target
      target = nil
    end
    result
  end
end

class Piece
    attr_reader :board,
                :color,
                :class_sym
  attr_accessor :pos,
                :value,
                :last_val

  def initialize(color, board, pos)
    @class_sym = self.class.to_s.to_sym
    @value = MATERIAL[class_sym]
    @color, @board, @pos = color, board, pos
    @board.add_piece(self, pos)
  end

  def line_key
    pk = ["a","b","c","d","e","f","g","h"][pos[1]] + (pos[0] + 1).to_s
    tk = (class_sym == :Knight ? "n" : self.class.to_s[0].downcase)
    "#{color.to_s[0]}_#{tk}_#{pk}"
  end

  def forward_dir
    (color == :white) ? -1 : 1
  end

  def render
    SYMBOLS[class_sym][color]
  end

  def positioning
    (color == :white ? SQUARES[class_sym][pos[0]][pos[1]] : SQUARES[class_sym][7 - pos[0]][pos[1]])
  end

  def positioning_after_move(new_pos)
    (color == :white ? SQUARES[class_sym][new_pos[0]][new_pos[1]] : SQUARES[class_sym][7 - new_pos[0]][new_pos[1]])
  end

  def symbols
    raise NotImplementedError
  end

  def valid_moves
    moves.reject { |to_pos| move_into_check?(to_pos) }
  end

  def is_valid_move?(to_pos)
    move_into_check?(to_pos) == false
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
    board.move_piece!(to_pos, original_pos)
    if target
      board[to_pos] = target
      target = nil
    end
    result
  end
end

require_relative 'library'
require 'json'
require 'rainbow'
require 'rainbow/ext/string'

class Board
  attr_accessor :rows,
                :material,
                :mv,
                :turns,
                :initial_depth,
                :best_move,
                :best_pos,
                :captures,
                :move_list,
                :depth_target,
                :timer,
                :eval_hash,
                :eval_data,
                :search_paths,
                :high_cutoffs,
                :low_cutoffs,
                :last_alpha

  attr_reader   :visits,
                :current_line,
                :openings,
                :white_king,
                :black_king

  def initialize
    @turns = 0
    @depth_target = 2
    @best_move
    @best_pos
    @last_alpha
    @move_list = []
    @true_move = false
    @timer = Time.new
    @rows = Array.new(8){Array.new(8)}
    @eval_hash = Hash.new {|h, k| h[k] = {
        white_piece_on: false,
        black_piece_on: false,
        white_in_range: 0,
        black_in_range: 0,
        white_king_adjacent: false,
        black_king_adjacent: false,
        age: 0
      }
    }

    # key will be turn number
    @high_cutoffs = Hash.new{|h, k| h[k] = {
        depth: 0,
        max: true
      }
    }

    # key will be turn number
    @low_cutoffs = Hash.new{|h, k| h[k] = {
        depth: 0,
        min: true
      }
    }

    # set key to turn + depth, to compare to similar
    @search_paths = Hash.new {|h, k| h[k] = {
        high: POS_INFINITY,
        low: NEG_INFINITY,
        max: true,
        depth: 0,
        turn: 0
      }
    }

    # update dynamically, clear when spread is too large or high
    # or a duration has expired
    @eval_data = Hash.new {|h, k| h[k] = {
        search_path: [],
        depth: 0,
        score: 0,
        white_captures: 0,
        black_captures: 0,
        white_king_threat: 0,
        black_king_threat: 0,
        white_positioning: 0,
        black_positioning: 0,
        age: 0
      }
    }
    @visits = Hash.new {|h, k| h[k] = {
      alpha_visits: 0,
      beta_visits: 0,
      evaluation: 0,
      num_beta: 0,
      num_alpha: 0,
      age: 0
      }
    }
    @captures = {
      white: [],
      black: []
    }
    @mv = {
      white: 0,
      black: 0
    }
    @material = {
       white: {
         Pawn: 8,
         Knight: 2,
         Bishop: 2,
         Rook: 2,
         Queen: 1,
         King: 1
       },
       black: {
         Pawn: 8,
         Knight: 2,
         Bishop: 2,
         Rook: 2,
         Queen: 1,
         King: 1
       }
     }
    @white_king
    @black_king
    @openings = Board.opening_book("openings.json")
    @lines =  @openings["w_p_e4"].first
    setup
  end

  def self.opening_book(filename)
    JSON.load(IO.read(filename))
  end

  #=====================================================================
  # player functions
  #=====================================================================

  def black_move(from_pos, to_pos)
    if valid_pos?(from_pos) && valid_pos?(to_pos) && self[from_pos]
      if self[from_pos].color != :white && self[from_pos].valid_moves.include?(to_pos)
        real_move!(from_pos, to_pos)
      else
        return false
      end
    else
      return false
    end
    true
  end
  DEPTH_INITIAL = 2
  DEPTH_DELTA = 2
  DEPTH_FINAL = 12


  #=====================================================================
  # search
  #=====================================================================
  def white_move!
    @best_pos, @best_move = nil, nil
    depth_target = DEPTH_INITIAL
    timer = Time.new
    score = search_max(NEG_INFINITY, POS_INFINITY, DEPTH_INITIAL)
    evaluate(true)
    time_elapsed = timer - Time.new

    real_move!(@best_pos, @best_move)
  end


  def search_max(alpha, beta, current_depth)
    if current_depth == 0
      return evaluate
    end
    target = nil
    selective(:white).each do |pos|
      piece = self[pos]
      next if piece.valid_moves.empty?
      piece.valid_moves.each do |move|
        if self[move]
          target = self[move]
        end
        move_piece!(pos, move)
        score = search_min(alpha, beta, current_depth - 1)
        undo!(move, pos)
        if target
          self[move] = target
          target = nil
        end
        if score >= beta
          return beta
        elsif score > alpha
          alpha = score
          if current_depth == depth_target
            @best_move = move
            @best_pos = pos
          end
        end
      end
    end
    alpha
  end

  def search_min(alpha, beta, current_depth)
    if current_depth == 0
      return  0 - evaluate
    end
    target = nil
    selective(:black).each do |pos|
      piece = self[pos]
      next if piece.valid_moves.empty?
      piece.valid_moves.each do |move|
        if self[move]
          target = self[move]
        end
        move_piece!(pos, move)
        score = search_max(alpha, beta, current_depth - 1)
        undo!(move, pos)
        if target
          self[move] = target
          target = nil
        end
        if score <= alpha
          return alpha
        elsif score < beta
          beta = score
        end
      end
    end
    beta
  end

  #=====================================================================
  # evaluation
  #=====================================================================

  def selective(color)
    coords = []
    pieces.sort_by{|p| -p.mv }.each do |piece|
      unless piece.color != color
        coords << piece.pos
      end
    end
    coords
  end


  # should mostly be the tiles adjacent to a king that have more pieces attacking than defending
  # if difference is > 1 then that should be a substantial increase
  def eval_king_danger
    white_king_threat, black_king_threat = 0, 0
    white_pawn_shield, black_pawn_shield = 0, 0

    @white_king.adjacent_tiles.each do |tile|
      white_king_threat = (eval_hash[tile[:black_in_range] - eval_hash[tile][:white_in_range])
      if white_king_threat > 1
    end
    @black_king.adjacent_tiles.each do |tile|
      black_king_threat = (eval_hash[tile[:white_in_range] - eval_hash[tile][:black_in_range])
    end

    king_threat - pawn_shield
  end

  def eval_threats
    white_threats = 0
    black_threats = 0
    @eval_board.each do |tile|
      white_threats += tile.black_in_range - tile.white_in_range
      black_threats += tile.white_in_range - tile.black_in_range
      if tile.black_in_range
  end

  def update_eval_hash
    other_color = :white
    pieces.each do |piece|
      if piece.color == :white
        eval_hash[piece.pos][:white_piece_on] = true
        eval_hash[piece.pos][:black_piece_on] = false
      else
        eval_hash[piece.pos][:white_piece_on] = false
        eval_hash[piece.pos][:black_piece_on] = true
      end

      if piece.valid_moves
        piece.valid_moves.each do |pos|
          if piece.color == :white
            eval_hash[pos][:white_in_range] += 1
          elsif piece.color == :black
            eval_hash[pos][:black_in_range] += 1
          end
        end
      end
    end
  end

  def clear_eval_board
    @eval_board.clear()
  end

  def evaluate(print_details = false)
    eval_white, eval_black = 0, 0

    update_eval_hash

    white_threats, black_threats = eval_threats

    white_positioning, black_positioning = eval_positioning

    material_imbalance = @mv[:white] - @mv[:black]

    white_king_danger = eval_king_danger(:white)
    black_king_danger = eval_king_danger(:black)


    w - b
  end




  #=====================================================================
  # normal board things
  #=====================================================================


  def checkmate?(color)
    return false unless in_check?(color)
    pieces.select { |p| p.color == color }.all? do |piece|
      piece.valid_moves.empty?
    end
  end

  def in_check?(color)
    king_pos = pieces.find{|p|p.pid == :king && p.color == color}.pos
    pieces.any? do |piece|
      piece.color != color && piece.moves.include?(king_pos)
    end
  end

  def real_move!(from_pos, to_pos)
    piece = self[from_pos]
    selected = piece.render
    capture = nil
    @turns += 1
    self[from_pos] = nil
    if self[to_pos]
      @captures[self[to_pos].color] << self[to_pos]
      capture = self[to_pos].render
    end
    @move_list << Board.parse_move(selected, piece.color, to_pos, capture)
    self[to_pos] = piece
    piece.pos = to_pos
    nil
  end


  def move_piece!(from_pos, to_pos)
    piece = self[from_pos]
    self[from_pos] = nil
    self[to_pos] = piece
    piece.pos = to_pos
    nil
  end

  def undo!(from_pos, to_pos)
    piece = self[from_pos]
    self[from_pos] = nil
    self[to_pos] = piece
    piece.pos = to_pos
    nil
  end








  #=====================================================================
  # utility
  #=====================================================================

  def setup
    PIECE_POSITIONS.each_with_index do |piece_class, column|
      white_pawn = Pawn.new(:white, self, [6, column], PAWN_ID[column])
      black_pawn = Pawn.new(:black, self, [1, column], PAWN_ID[column])
      white_piece = piece_class.new(:white, self, [7, column], PIECE_ID[column])
      black_piece = piece_class.new(:black, self, [0, column], PIECE_ID[column])
      mv[:white] += white_piece.value
      mv[:black] += black_piece.value
      if piece_class == King
        @white_king = white_piece
        @black_king = black_piece
      end
    end
  end

  def find_king(color)
    pieces.find{|p|p.pid == :king && p.color == color}
  end

  def [](pos)
    fail 'invalid pos' unless valid_pos?(pos)
    i, j = pos
    @rows[i][j]
  end

  def []=(pos, piece)
    fail 'invalid pos' unless valid_pos?(pos)
    i, j = pos
    @rows[i][j] = piece
  end

  def add_piece(piece, pos)
    self[pos] = piece
  end

  def empty?(pos)
    self[pos].nil?
  end

  def pieces
    @rows.flatten.compact
  end

  def valid_pos?(pos)
    pos.all? { |coord| coord.between?(0, 7)}
  end

  #=====================================================================
  # display
  #=====================================================================

  def self.parse_move(selected, color, to_pos, capture)
    selected += "   →  " + "abcdefgh"[to_pos[1]] + (to_pos[0] + 1).to_s
    if capture
      selected += capture
    end
    clr = (color == :white ? "◈  ".color(170,170,170) : "◈  ".color(:black))
    clr + selected
  end

  def self.border(top)
    b = ""
    b += " │" + (" " * 32) + "│\n" unless top
    top ? b += " ┌" : b += " └"
    b += ("─" * 32)
    top ? b += "┐ " : b += "┘"

    if @captures
      b += (top ? @captures[:white].join(' ') : @captures[:black].join(' '))
    end
    b += "\n │" + (" " * 32) + "│" if top
    b.color(170,170,170)
  end

  def self.file_markers
    "\n │     #{FILES.join(" ")}    │".color(170,170,170)
  end

  def self.rank_marker(idx, left)
    s = "#{RANKS[7 - idx]}".background(:default).color(170,170,170)
    s = (left ? " │  ".color(170,170,170) + s : s + "  │".color(170,170,170))
    unless left
      if @move_list
        if @move_list.length > 1
          s += @move_list[-idx]
        end
      end
    end
    s
  end

  def self.tile(on, contents, piece_on, piece_target)
    fill = " #{contents} "
    if piece_target
      if on
        return fill.bright.background(80,80,80).color(:white)
      else
        return fill.background(80,80,80).color(:white)
      end
    elsif piece_on
      return fill.bright.background(:white).color(:blue)
    else
      return on ? fill.background(:white).color(:black) : fill.background(200,200,200).color(:black)
    end
  end

  def render(player, accents = nil)
    if accents && self[accents] && player
      accent_pos = self[accents].valid_moves
    end
    current = nil
    on = true
    highlight = false
    r = []
    r << Board.border(true)
    r << Board.file_markers

    @rows.reverse.each_with_index do |row, row_idx|
      r << "\n" + Board.rank_marker(row_idx, true)
      row.each_with_index do |tile, tile_idx|
        current = [7 - row_idx, tile_idx]
        piece_on = false
        if accent_pos
          highlight = (accent_pos.include?(current) && accents != current)
        else
          highlight = false
        end
        unless accents.nil?
          piece_on = true if accents == current
        end
        content = (self[current] ? self[current].render : " ")
        r << Board.tile(on, content, piece_on, highlight)
        on = on ? false : true
      end
      on = on ? false : true
      r << Board.rank_marker(row_idx, false)
    end
    r << Board.file_markers + "\n"
    r << Board.border(false)
    r.join("")
  end
end

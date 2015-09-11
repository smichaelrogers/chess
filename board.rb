require_relative 'library'
require 'json'
require 'rainbow'
require 'rainbow/ext/string'
require 'byebug'
class Board
  attr_accessor :rows, :material, :depth_target, :captures, :alpha_adj, :beta_adj, :move_list, :timer, :visits, :white_visits, :black_visits, :last_move, :lines, :first_move, :best_pos, :best_move, :openings, :following_opening
  attr_reader :openings, :white_king, :black_king, :render_data

  def initialize
    @rows = Array.new(8){Array.new(8)}
    @visits = Array.new(8){Array.new(8){ {white: 0, black: 0} } }
    @move_list = Array.new([])
    @material = {
      Pawn: 0,
      Knight: 0,
      Bishop: 0,
      Rook: 0,
      Queen: 0,
      King: 0
    }
    @captures = {
      white: [],
      black: []
    }
    @following_opening = true
    @render_data = false
    @first_move = true
    @depth_target = 0
    @alpha_adj, @beta_adj = NEG_INFINITY, POS_INFINITY
    @timer = Time.new
    @white_visits, @black_visits = 1, 1
    @openings = Board.opening_book("openings.json")
    @lines = @openings
    setup
  end

  def self.opening_book(filename)
    JSON.load(IO.read(filename))
  end


  #=====================================================================
  # player functions
  #=====================================================================
  def black_move(from_pos, to_pos)
    real_move!(from_pos, to_pos)
    @last_move = self[to_pos].line_key
  end

  def white_move!
    @depth_target = 4
    unless move_available?
      @timer = Time.new
      @alpha_adj, @beta_adj = NEG_INFINITY, POS_INFINITY
      @white_visits, @black_visits = 1, 1
      score = search(alpha_adj, beta_adj, @depth_target, true)
      evaluate(true)
    end
    real_move!(@best_pos, @best_move)
    reset_search_data
  end

  def reset_search_data
    white_visits, black_visits = 1, 1
    visits.each { |row| row.each {|tile| tile[:white], tile[:black] = 0, 0 } }
  end

  def move_available?
    return false unless following_opening
    if first_move
      @lines = lines["w_p_e4"]
      @first_move = false
      @best_pos, @best_move = [6, 4], [4, 4]
      return true
    end
    if @lines.nil?
      @following_opening = false
    elsif @lines[last_move]
      @lines = @lines[last_move]
      m = @lines.first
      d = parse_move(m.first)
      if d
        piece = pieces.find do |n|
          n.color == d[:color] && n.class_sym == d[:piece] && n.valid_moves && n.valid_moves.include?(d[:pos])
        end
        if piece
          @best_pos, @best_move = piece.pos, d[:pos]
          return true
        end
      end
    else
      @following_opening = false
    end
    false
  end


  #=====================================================================
  # search
  #=====================================================================
  def search(alpha, beta, depth, maximizing)
    if depth <= 0
      return maximizing ? evaluate : -evaluate
    end
    current_color = maximizing ? :white : :black
    target, moves = nil, order_moves(current_color)
    moves.each do |m|
      pos, move = m[0], m[1]
      piece = self[pos]
      if self[move]
        target = self[move]
        @material[target.class_sym] += (maximizing ? 1 : -1)
      end
      move_piece!(pos, move)
      score = search(alpha, beta, depth - 1, !maximizing)
      move_piece!(move, pos)
      if target
        @material[target.class_sym] += (maximizing ? -1 : 1)
        self[move] = target
        target = nil
      end
      if maximizing
        @white_visits += 1
        @visits[move[0]][move[1]][:white] += 1
        if score >= beta
          return beta
        elsif score > alpha
          alpha = score
          if depth == depth_target
            @best_pos, @best_move = pos, move
          end
        end
      else
        @black_visits += 1
        @visits[move[0]][move[1]][:black] += 1
        if score <= alpha
          return alpha
        elsif score < beta
          beta = score
        end
      end
    end
    maximizing ? alpha : beta
  end

  #=====================================================================
  # evaluation
  #=====================================================================

  def order_moves(color)
    if color == :white
      other_color, other_total_visits, total_visits = :black, black_visits, white_visits
    else
      other_color, other_total_visits, total_visits = :white, white_visits, black_visits
    end
    moves = []
    friends, enemies, rating = 0, 0, 0
    pc = pieces.select{|p| p.color == color}
    pc.each do |piece|
      piece.valid_moves.each do |move|
        friends = @visits[move[0]][move[1]][color] / total_visits
        enemies = @visits[move[0]][move[1]][other_color] / other_total_visits
        rating = (8 * (friends - enemies)) + piece.positioning_after_move(move)
        moves << [piece.pos, move, rating]
      end
    end
    moves.sort_by { |m| -m[2] }
  end

  def eval_positioning
    n, wv, bv = 0, 0, 0
    pieces.each do |p|
      n += ( p.color == :white ? p.positioning : 0 - p.positioning )
      wv += @visits[p.pos[0]][p.pos[1]][:white]
      bv += @visits[p.pos[0]][p.pos[1]][:black]
    end
    (n + (((wv / white_visits) - (bv / black_visits)) * 160.0)) / 6.0
  end

  def eval_king_threat
    n = 0.0
    wv, bv = 0.0, 0.0
    white_king.adjacent_tiles.each do |tile|
      wv, bv = @visits[tile[0]][tile[1]][:white], @visits[tile[0]][tile[1]][:black]
      n += (((wv / white_visits) - (bv / black_visits)) * 64.0)
    end
    black_king.adjacent_tiles.each do |tile|
      wv, bv = @visits[tile[0]][tile[1]][:black], @visits[tile[0]][tile[1]][:white]
      n -=  (((bv / black_visits) - (wv / white_visits)) * 64.0)
    end
    n
  end

  def evaluate(print_details = false)
    positioning = eval_positioning
    king_safety = eval_king_threat
    mi = @material[:Pawn] * MATERIAL[:Pawn] +
    @material[:Knight] * MATERIAL[:Knight] +
    @material[:Bishop] * MATERIAL[:Bishop] +
    @material[:Rook] * MATERIAL[:Rook] +
    @material[:Queen] * MATERIAL[:Queen] +
    @material[:King] * MATERIAL[:King]
    score = mi + positioning + king_safety
    if print_details && render_data
      print_eval_data({mi: mi, positioning: positioning, king_safety: king_safety, score: score})
    end
    score
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
    king_pos = color == :white ? white_king.pos : black_king.pos
    pieces.any? do |piece|
      piece.color != color && piece.moves.include?(king_pos)
    end
  end

  def real_move!(from_pos, to_pos)
    piece = self[from_pos]
    selected = piece.render
    capture, self[from_pos] = nil, nil
    if self[to_pos]
      @material[self[to_pos].class_sym] += (piece.color == :white ? 1 : -1)
      capture = self[to_pos].render
      @captures[self[to_pos].color] << capture
    end
    @move_list << Board.parse_to_render(selected, piece.color, to_pos, capture)
    self[to_pos] = piece
    last_move = "#{piece.color.to_s[0]}_#{piece.is_a?(Knight) ? 'n' : piece.class.to_s.downcase[0]}_#{'abcdefgh'[to_pos[1]]}#{to_pos[0] + 1}"
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


  #=====================================================================
  # utility
  #=====================================================================

  def setup
    PIECE_POSITIONS.each_with_index do |piece_class, column|
      Pawn.new(:white, self, [6, column])
      Pawn.new(:black, self, [1, column])
      white_piece = piece_class.new(:white, self, [7, column])
      black_piece = piece_class.new(:black, self, [0, column])
      if piece_class == King
        @white_king = white_piece
        @black_king = black_piece
      end
    end
  end

  def parse_move(move)
    return false if move.length != 6
    m = {}
    move[0] == "w" ? m[:color] = :white : m[:color] = :black
    m[:piece] = PIECE_KEY[move[2].to_sym]
    m[:pos] = [(7 - move[5].to_i + 1), move[4].ord - 97]
    m
  end

  def find_king(color)
    color == :white ? white_king : black_king
  end

  def [](pos)
    fail unless valid_pos?(pos)
    i, j = pos
    rows[i][j]
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
  # stdout
  #=====================================================================

  def self.parse_to_render(selected, color, to_pos, capture)
    selected += "   →  " + "abcdefgh"[to_pos[1]] + (to_pos[0] + 1).to_s
    if capture
      selected += capture
    end
    clr = (color == :white ? "◈  ".color(170,170,170) : "◈  ".color(:black))
    clr + selected
  end

  def display_data(toggle = true)
    @render_data = toggle
  end

  def print_eval_data(data)
    r0, r1, r2, h = [], [], [], []
    h << "M:#{data[:mi]} P:#{data[:positioning]} K:#{data[:king_safety]} S:#{data[:score]}"
    @visits.each_with_index do |visit, i|
      r1.clear; r2.clear
      visit.each_with_index do |tile, j|
        r1 << "W#{tile[:white].to_s.ljust(3, ' ')}"[0, 4]
        r2 << "B#{tile[:black].to_s.ljust(3, ' ')}"[0, 4]
      end
      r0 << "|" + r1.join("|") + "|\n|" + r2.join("|") + "|"
    end
    puts move_list
    unless following_opening
      puts " ══════════════════════════════════"
      puts r0.join("\n|" + ("----|" * 8) + "\n")
      puts " ══════════════════════════════════"
    end
    puts h.join(" | ")
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
    @move_list ||= []
    s = "#{RANKS[7 - idx]}".background(:default).color(170,170,170)
    s = (left ? " │  ".color(170,170,170) + s : s + "  │".color(170,170,170))
    unless left
      if idx < @move_list.length
        s += @move_list[idx]
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
      return fill.bright.background(:white).color(:cyan)
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

require 'json'
fn = ["NebulaE_100_Short.pgn", "Blitz_Testing_4moves.pgn", "GBDC12013.pgn", "GrandPQRS-3moves-2358.pgn", "MLmfl.pgn", "NebulaE_100_Long.pgn", "NebulaE_100_Medium.pgn", "NebulaH_100_Long.pgn", "NebulaH_100_Medium.pgn", "NebulaH_100_Short.pgn", "Noomen_Testsuite_2012.pgn", "Noomen_Topical_Testsuite_2012.pgn", "Nunn_Openings.pgn", "Silver_Suite.pgn", "swcr-fq-openings-v4.1.pgn"]
output = "openings.json"
columns = ["a", "b", "c", "d", "e", "f", "g", "h"]
rows = ["1", "2", "3", "4", "5", "6", "7", "8"]
pieces = ["K", "Q", "R", "B", "N"]
id = {
  P: "p_",
  N: "n_",
  B: "b_",
  R: "r_",
  K: "k_",
  Q: "q_"
}
lines = []
fn.each do |file|
  f = File.new("lib/#{file}")
  f.readlines.each do |line|
    next if line[0] == "["
    lines << line
  end
end
moves = {}
all = []
lines.each_with_index do |line, line_idx|
  remaining = line
	current_line = []
  (2..20).each do |idx|
	   current = []
    first, second = "", ""
    cutoff = idx.to_s + "."
    break unless remaining.include?(cutoff)
    current = remaining.split(cutoff).first.split(" ")
    remaining = line.split(cutoff).last
    current = current[1..2] if current.include?("1.")
		break unless current.flatten.compact.length > 1
    break if current[0].nil?
    current.each_index do |i|
      current[i].gsub!(/[^a-wA-W0-9\s]/, "")
      if columns.include?(current[i][-2]) && rows.include?(current[i][-1])
		    str = ""
        str = (columns.include?(current[i][0]) ? "P" : current[i][0])
        str += current[i][-2] + current[i][-1].to_s
        break unless id.keys.include?(str[0].to_sym)
        if !id[str[0].to_sym]
          p str[0]
        end
        str = id[str[0].to_sym] + str[1..-1]
        i == 0 ? first += str : second += str
      end
    end
    next if (first + second).length < 6
    first = "w_#{first}"
    second = "b_#{second}"

		current_line << first
    current_line << second
  end

	all << current_line if current_line.length > 1
end
result = []
tree = {}
first_moves = []
all.each do |line|
  first_moves << line[0]
end
first_moves = first_moves.uniq
first_moves.each_with_index do |move|
  tree[move] = {}
end
all.each do |line|
  search_tree(tree[line[0]], line)
end
BEGIN {
  def search_tree(hash, array)
    return if array.length == 0
    return if array[0].length != 6
    if array[1]
      return if array[1].length != 6
    end
    unless hash.has_key?(array[0])
      hash[array[0]] = {}
      search_tree(hash[array[0]], array.drop(1))
    else
      search_tree(hash[array[0]], array.drop(1))
    end
  end
}

rslt = {moves: {}}
tree.each do |key, val|
  if tree[key].has_key?(key)
    rslt[:moves][key] = tree[key][key]
  else
    rslt[:moves][key] = tree[key]
  end
end

o = File.open(output, "w")
o.puts ""
o.close
o = File.open(output, "a")
o.puts JSON.generate(rslt)
o.close

require 'set'
input     = ARGF.read.split("\n")
num_rules = input[0].to_i
cfg_rules = input[1..num_rules]
smap      = input[num_rules+1..]

# Transfer rules to hash dictionary
def to_dictionary(grammar,cfg)
  grammar.each do |prod|
    l,r = prod.split(' -> ')
    if cfg.key?(l)
      if r != nil
        cfg[l] << r
      else
        cfg[l] << ''
      end
    else
      if r != nil
        cfg[l] = [r]
      else
        cfg[l] = ['']
      end
    end
  end
end

# Remove lambda rules
def remove_lambda(cfg)
  eps = cfg.select {|_,x| x.include?('') }.keys
  until eps.empty?
    eps.each do |key|
      cfg[key].delete('')
      cfg.each do |_,list|
        tmp = []
        list.each do |x|
          tmp << x.gsub(key,'') if x.include?(key)
        end
        list.concat(tmp)
      end
    end
    eps = cfg.select {|_,x| x.include?('') }.keys
  end
end

# Remove unit rules
def remove_unit(cfg)
  unit = {}
  cfg.each {|key,list| list.each {|x| unit[key] = x if x.match(/^[A-Z]$/)}}
  unit.each do |key,list|
    t1 = list
    t2 = ''
    until t1.match(/[a-z]/)
      cfg[t1].each do |x|
        if (x.size == 1 && x.match(/[A-Z]/)) || x.match(/[a-z]/)
          t2 = t1
          t1 = x
        end
      end
    end
    cfg[key].delete(t2)
    cfg[key] << t1
  end
end

# Check if in CNF
def cnf?(cfg)
  cfg.each do |k,l|
    l.each do |v|
      return false if v.size > 2
    end
  end
  return true
end

# Removes duplicate rules
def remove_duplicates(cfg)
  cfg.dup.each do |k0,l0|
    cfg.dup.each do |k1,l1|
      if k1 != k0 && l0.size == 1 && l0 == l1
        cfg.reject! {|k2,_| k2 == k0 }
        cfg.each do |k,l|
          l.each do |s|
            if s.size > 1
              s.gsub!(k0, k1)
            end 
          end
        end
      end
    end
  end
end

# Convert CFG to CNF
def cnfify(cfg)
  # Get Terminals
  term = Set.new
  cfg.each {|k,l| l.each {|v| v.each_char {|t| term << t if t.match(/[a-z]/)}}}
  term.each do |t|
    #(0.chr..255.chr).each do |j|
    ('A'..'Z').each do |j|
      if !cfg.member?(j)
        cfg[j] = [t]
        break
      end
    end
  end
  # Replace long terminal rules with non terminals
  cfg.each do |_,list|
    list.each do |str|
      chars = []
      str.each_char {|c| chars << c if !chars.include?(c) && c.match(/[a-z]/)}
      if str.match(/[a-zA-Z]{2,}/)
        chars.each do |chr|
          cfg.each do |key,l|
            if l.size == 1 && l[0] == chr
              str.gsub!(chr, key)
              break
            end
          end
        end
      end
    end
  end
  # Replace long non-terminal rules
  until cnf?(cfg) do
    cfg.dup.each do |k,l|
      l.each do |s|
        if s.size > 2
          #g = cfg.select {|k,l| cfg[k].size==1 && l[0] {|v| v==s[1..s.size]}}
          #if g.first[0].size > 0
          #  cfg[k].delete(s)
          #  cfg[k] << "#{s[0]}#{g.first[0]}"
          #  break
          #else
            ('A'..'Z').each do |c|
            #(0.chr..255.chr).each do |c|
              if !cfg.member?(c)
                cfg[c] = [s[1..s.size]]
                cfg[k].delete(s)
                cfg[k] << "#{s[0]}#{c}"
                break
              end
            end
          #end
        end
      end
    end
  end
  # Remove duplicates
  remove_duplicates(cfg)
end

# CYK-Parse the grammar and words
def cyk(cfg,w)
    n = w.size
    table = Array.new(n) { Array.new(n) { Set.new } }
    (0...n).each do |x|
      cfg.each do |key,list|
        list.each do |str|
          if str.size == 1 && str[0] == w[x]
            table[x][x] << key
            break
          end
        end
      end
      x.downto(0).each do |y|
        (y...x).each do |z|
          cfg.each do |key,list|
            list.each do |str|
              if str.size == 2 && table[y][z].include?(str[0]) && table[z+1][x].include?(str[1])
                table[y][x] << key
              end
            end
          end
        end
      end
    end
    longest = ''
    (0...n).each do |i|
      (n-1).downto(i).each do |j|
        if table[i][j]===cfg.first[0]
          if w[i..j].size > longest.size
            longest = w[i..j]
          else
            break
          end
        end
      end
    end
    if longest.size > 0
      return longest
    else
      return 'NONE'
    end
end

cfg = {}

to_dictionary(cfg_rules, cfg)
remove_lambda(cfg)
remove_unit(cfg)
cnfify(cfg)

threads = []
array = []

# Start threads
smap.size.times do |i|
  threads[i] = Thread.new { array[i] = cyk(cfg, smap[i])}
end
threads.each(&:join)

# Print results
array.each do |string|
  puts string
end

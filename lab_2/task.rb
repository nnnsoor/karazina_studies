def cut(cake)
  h, w = cake.size, cake[0].size
  raisins = []
  h.times { |i| w.times { |j| raisins << [i, j] if cake[i][j] == 'o' } }
  n = raisins.size
  return [] if (h * w) % n != 0
  area = h * w / n

  rects = []
  (1..h).each do |hh|
    next unless area % hh == 0
    ww = area / hh
    next if ww > w
    (0..h - hh).each do |r|
      (0..w - ww).each do |c|
        rs = raisins.select { |ri, rj| ri.between?(r, r + hh - 1) && rj.between?(c, c + ww - 1) }
        rects << [r, r + hh - 1, c, c + ww - 1] if rs.size == 1
      end
    end
  end

  best = nil
  best_width = -1

  search = lambda do |used, covered, pieces|
    if pieces.size == n
      if covered.flatten.all?
        first_w = pieces[0][0].size
        if first_w > best_width
          best_width = first_w
          best = pieces.map(&:dup)
        end
      end
      return
    end

    r, c = nil, nil
    h.times do |i|
      w.times do |j|
        unless covered[i][j]
          r, c = i, j
          break
        end
      end
      break if r
    end
    return unless r

    rects.each do |r1, r2, c1, c2|
      next if used[[r1, r2, c1, c2]]
      next unless r.between?(r1, r2) && c.between?(c1, c2)

      next if (r1..r2).any? { |i| (c1..c2).any? { |j| covered[i][j] } }

      used[[r1, r2, c1, c2]] = true
      (r1..r2).each { |i| (c1..c2).each { |j| covered[i][j] = true } }

      piece = (r1..r2).map { |i| cake[i][c1..c2] }
      pieces << piece

      search.call(used, covered, pieces)

      pieces.pop
      used[[r1, r2, c1, c2]] = false
      (r1..r2).each { |i| (c1..c2).each { |j| covered[i][j] = false } }
    end
  end

  search.call({}, Array.new(h) { Array.new(w, false) }, [])
  best || []
end


cake1 = [
  "........",
  "..o.....",
  "...o....",
  "........"
]
puts "Результат 1:"
p cut(cake1)
puts

cake2 = [
  ".o......",
  "......o.",
  "....o...",
  "..o....."
]
puts "Результат 2:"
p cut(cake2)
puts

cake3 = [
  ".o.o....",
  "........",
  "....o...",
  "........",
  ".....o..",
  "........"
]
puts "Результат 3:"
p cut(cake3)
puts

cake4 = [
  ".o.o....",
  ".o.o....",
  "........",
  "........",
  "........",
  "........"
]
puts "Результат 4 (має бути []):"
p cut(cake4)

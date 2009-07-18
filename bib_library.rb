# Bibliography entry handler

class BibEntry < Array
  attr_reader :tag, :citekey, :lines
  def initialize(tag, citekey, lines)
    @tag = tag
    @citekey = citekey
    @lines = lines
  end

  def out(o)
    o.puts "%"*(78 - @citekey.size) + " #{@citekey}"
    o.puts ""
    @lines.each {|l| o.puts l}
    o.puts ""
  end

  def to_s
    "@#{@tag} #{@citekey}"
  end

end

class BibLibrary < Array

  def initialize(file = nil, encoding = "r")
    if file != nil
      read(file, encoding)
    end
  end

  def read(file, encoding = "r")
    lines = nil
    inside = false
    tag = "?"
    citekey = "?"
    open(file, encoding) do |f|
      f.each do |l|
        if l =~ /^%/
          # comments
        elsif l =~ /^\s+$/
          # blank lines
        else 
          if l =~ /^\@([A-Za-z]+)\{([^,]+),$/
            tag, citekey = $1, $2
            lines = [ ]
            inside = true
          end

          lines.push(l) if inside
          
          if l =~ /^\}$/
            self.push(new_bib(tag, citekey, lines))
            lines = nil
            inside = false
          end
        end
      end
    end
    postread
  end

  def new_bib(tag, citekey, lines)
    BibEntry.new(tag, citekey, lines)
  end

  def postread
  end

  def out(o)
    self.sort{|a,b| a.citekey.capitalize <=> b.citekey.capitalize }.each {|e| e.out(o) }
  end

  def to_s
    self.map {|b| b.to_s}.join("\n")
  end

end

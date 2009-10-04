# Bibliography entry handler

class BibEntry < Array
  attr_reader :tag, :citekey, :lines
  def initialize(lib, tag, citekey, lines)
    @lib = lib
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
  attr_reader :keywords_re

  def initialize(file = nil, opts)
    @opts = opts
    encoding = "r:"+opts[:encoding]
    if file != nil
      kfile = opts[:key_file]
      if kfile == ""
        kfile = File.basename(file, ".bib")+"-keywords.txt"
      end
      if File.file?(kfile)
        read_key(kfile, encoding)
      end
      read(file, encoding)
    end
  end

  def read_key(file, encoding = "r")
    @keywords = Array.new
    open(file, encoding) do |f|
      f.each do |l|
        l.chomp!
        unless l =~ /^\s*(#|%)/
          @keywords.push(l)
        end
      end
    end
    @keywords_re = Regexp.new("("+@keywords.join("|")+")")
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
    BibEntry.new(self,tag, citekey, lines)
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

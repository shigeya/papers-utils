# Bibliography entry handler

class BibEntry < Array
  attr_reader :tag, :citekey, :lines
  def initialize(lib, tag, citekey, lines)
    @lib = lib
    @tag = tag
    @citekey = citekey
    @lines = lines
  end

  def prep
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

  def write_opt(opts)
    "w" + ( opts.has_key?(:output_encoding) ? ":"+opts[:output_encoding] : "")
  end

  def write_to_file(file, opts, marker_lines = [])
    STDERR.puts "Writing citation <#{@citekey}> to #{file}"
    open(file, write_opt(opts)) do |f|
      @lines.each {|l| f.puts l unless l =~ /^}/ }
      marker_lines.each {|l| f.puts l }
      f.puts "}"
    end
  end

end

class BibLibrary < Hash
  attr_reader :keywords_re

  def read_opt(opts)
    "r" + ( opts.has_key?(:encoding) ? ":"+opts[:encoding] : "")
  end

  def initialize(file = nil, opts)
    @opts = opts
    ropt = read_opt(opts)
    if file != nil
      kfile = opts[:key_file]
      if kfile == ""
        kfile = File.basename(file, ".bib")+"-keywords.txt"
      end
      if File.file?(kfile)
        read_key(kfile, ropt)
      end
      read(file, ropt)
    end
  end

  def read_key(file, encoding = "r")
    @keywords = Array.new
    open(file, encoding) do |f|
      f.each do |l|
        l.chomp!
        unless l =~ /^\s*(#|%)/ || l =~ /^\s*$/
          @keywords.push(l)
        end
      end
    end
    @keywords_re = Regexp.new("("+@keywords.join("|")+")")
  end

  def read(file, read_opt)
    lines = nil
    inside = false
    tag = "?"
    citekey = "?"
    open(file, read_opt) do |f|
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
            self[citekey] = new_bib(tag, citekey, lines)
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

  def prep(o)
    self.each {|k, v| v.prep }
  end

  def out(o)
    self.keys.sort.each {|k| self[k].out(o) }
  end

  def to_s
    self.keys.sort.each{|k| self[k].to_s }.join("\n")
  end

end

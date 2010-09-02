# Bibliography entry handler

require 'date'
require 'digest/md5'

class BibEntry < Array
  attr_reader :tag, :citekey, :lines, :hash
  attr_reader :date_added, :date_processed, :date_modified

  def initialize(lib, tag, citekey, lines)
    @lib = lib
    @tag = tag
    @citekey = citekey
    @lines = lines
    @date_added = 0
    @date_modified = 0
    @date_processed = 0
    @hash = 0
  end

  def prep
    # create digest of the object, ignoring date related fields
    @hash = Digest::MD5.new

    # Parsing several dates
    @lines.each do |line|
      if line =~ /\s*date-(\S+)\s*=\s*{\s*(.+)\s*}/
        k, d = $1, DateTime.parse($2)
        if k == "added"
          @date_added = d
        elsif k == "modified"
          @date_modified = d
        elsif k == "written-via-bibdump"
          @date_processed = d
        end
      else
        @hash.update(line)
      end
    end
  end

  def out(o)
    o.puts "% " + "-"*(76 - @citekey.size) + " #{@citekey}"
    o.puts ""
    @lines.each {|l| o.puts l}
    o.puts ""
  end

  def to_s
    @lines.join("")
  end

  def write_opt(opts)
    "w" + ( opts.has_key?(:output_encoding) ? ":"+opts[:output_encoding] : "")
  end

  def write_to_file(file, opts, marker_lines = [])
    STDERR.puts "Writing citation <#{@citekey}> to #{file}"
    open(file, write_opt(opts)) do |f|
      @lines.each {|l| f.puts l unless l =~ /^}\s*$/ }
      marker_lines.each {|l| f.puts l }
      f.puts "}"
    end
  end

  # equality means: contents other than date fields match exactly
  def ==(x)
    if hash == x.hash
      if @date_added == x.date_added and 
          @date_modified == x.date_modified
        return true
      else
      end
    else
      STDERR.puts "<#{citekey}> Hash Mismatch: #{hash} #{x.hash}"
      return false
    end

    false
  end

  # Minimum sanity check here.
  # if it is not equal, there must be some date mismatch..
  # returns if paper's entry is newer then locally edited bibs,
  # added > modified, and date added should be same.
  def inconsistent?(x)
    if @date_added > @date_modified or
        x.date_added > x.date_modified or
        @date_added != x.date_added or
        @date_modified > x.date_modified
      return true
    end
    false
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
    self.prep
  end

  def prep
    self.each {|k, v| v.prep }
  end

  def out(o)
    self.keys.sort.each {|k| self[k].out(o) }
  end

  def to_s
    self.keys.sort.each{|k| self[k].to_s }.join("\n")
  end


  # Merge entire BibLibrary onto self
  def merge(xlib)
    xlib.each_value { |v| merge_one(v) }
  end

  # Merge one entry onto self
  def merge_one(n)

    # if the primary library (self) does not contain the entry, don't merge
    # unless --merge option given
    citekey = n.citekey
    unless self.has_key?(citekey) and @opts[:add] == false
      STDERR.puts "<#{n.citekey}> do not exist in primary bib file. use --add to force adding them"
    else
      old = self[citekey]
      if old == n               # if contents is same.. don't replace
        STDERR.puts "Skiping: <#{citekey}>"
      elsif old.inconsistent?(n)
        STDERR.puts "Inconsistent: <#{citekey}>"
        if @opts[:dump_mismatch]
          STDERR.puts "----- #{old.hash}"
          STDERR.puts old.to_s
          STDERR.puts "----- #{n.hash}"
          STDERR.puts n.to_s
        end
      else
        if @opts[:dump_mismatch]
          STDERR.puts "----- #{old.hash}"
          STDERR.puts old.to_s
          STDERR.puts "----- #{n.hash}"
          STDERR.puts n.to_s
        end

        if @opts[:overwrite] # dont overwrite unless specified
          STDERR.puts "Replacing: <#{citekey}>"
          self[citekey] = n
        else
          STDERR.puts "*NOT* Replacing: <#{citekey}> -- use --overwrite to replace"
        end
      end
    end
  end

  def mkbibpath(c)
    if ! ( c =~ /\.bib$/ )
      return @opts[:bib_dir] + "/" + c + ".bib"
    elsif File.file?(c)
      return c
    elsif File.file?(@opts[:bib_dir] + "/" + c)
      return @opts[:bib_dir] + "/" + c
    end
    c
  end

end

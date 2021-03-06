# Bibliography entry handler

require 'date'
require 'digest/md5'

class BibEntry < Array
  attr_reader :tag, :citekey, :lines, :bib_hash, :title, :author, :authors
  attr_reader :date_added, :date_processed, :date_modified

  def initialize(lib, tag, citekey, lines)
    @lib = lib
    @tag = tag
    @citekey = citekey
    @lines = lines
    @date_added = 0
    @date_modified = 0
    @date_processed = 0
    @bib_hash = 0
    @title = ""
    @author = ""
  end

  def prep
    # create digest of the object, ignoring date related fields
    @bib_hash = Digest::MD5.new

    # Parsing several dates and some important fields
    @lines ||= [ ]
    @lines.each do |line|
      if line =~ /\s*booktitle\s*=\s*{(.*)},?\s*$/
        @booktitle = $1
        @booktitle.gsub!(/\{*/, '')
        @booktitle.gsub!(/\},/, '')
      elsif line =~ /\s*title\s*=\s*{(.*)},?\s*$/
        @title = $1
        @title.gsub!(/\{/, '')
        @title.gsub!(/\}/, '')
      elsif line =~ /\s*author\s*=\s*{(.*)},?\s*$/
        @author = $1
        @author.gsub!(/\{/, '')
        @author.gsub!(/\}/, '')
        @authors = @author.split(/ and /)
      elsif line =~ /\s*date-(\S+)\s*=\s*{\s*(.+)\s*}/
        k, d = $1, DateTime.parse($2)
        if k == "added"
          @date_added = d
        elsif k == "modified"
          @date_modified = d
        elsif k == "written-via-bibdump"
          @date_processed = d
        end
      else
        @bib_hash.update(line)
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
      @lines.each {|l| f.puts l unless l =~ /^}\s*$/ } if @lines != nil
      marker_lines.each {|l| f.puts l }
      f.puts "}"
    end
  end

  # equality means: contents other than date fields match exactly
  def ==(x)
    if @bib_hash == x.bib_hash
      if @date_added == x.date_added and 
          @date_modified == x.date_modified
        return true
      else
      end
    else
      STDERR.puts "<#{citekey}> Bib_Hash Mismatch: #{bib_hash} #{x.bib_hash}"
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
        x.date_added > x.date_modified
#        @date_added != x.date_added or
#        @date_modified > x.date_modified

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

    begin
      open(bibpathnormalize(file), read_opt) do |f|
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
    rescue ArgumentError
      STDERR.puts "invalid byte sequence in #{file}"
      exit 1
    end
    postread if self.size != 0
  end

  def new_bib(tag, citekey, lines)
    BibEntry.new(self,tag, citekey, lines)
  end

  def postread
    prep
  end

  def prep
    each {|k, v| v.prep }
  end

  def out(o)
    keys.sort.each {|k| self[k].out(o) }
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
      if old.bib_hash == n.bib_hash               # if contents is same.. don't replace
        STDERR.puts "Skiping: <#{citekey}>"
      elsif old.inconsistent?(n)
        STDERR.puts "Inconsistent: <#{citekey}>"
        if @opts[:dump_mismatch]
          STDERR.puts "----- #{old.bib_hash}"
          STDERR.puts old.to_s
          STDERR.puts "----- #{n.bib_hash}"
          STDERR.puts n.to_s
        end
      else
        if @opts[:dump_mismatch]
          STDERR.puts "----- #{old.bib_hash}"
          STDERR.puts old.to_s
          STDERR.puts "----- #{n.bib_hash}"
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

  def bibpathnormalize(c)
     c.gsub(/:/, "_")
  end

  def bibdirpath(s)
    @opts[:bib_dir] + "/" + s + ".bib"
  end

  def mkbibpath_1(c, suffix, wflag = false)
    return nil if c == nil
    fn = @opts[:bib_dir] + "/" + c + "." + suffix
    if wflag == nil
      return fn if File.file?(fn)
    else # only check for existing of directory
      return fn if File.directory?(File.dirname(fn))
    end

    return nil
  end


  def mkbibpath(c, wflag = false)
    s = bibpathnormalize(c)
    r = nil
    if @opts[:group] != nil
      p = mkbibpath_1(s, "#{@opts[:group]}-bib", wflag)
      if File.file?(p)
        STDERR.puts "Found: group <#{@opts[:group]}> variant for #{s}"
        r = p
      end
    end
    r = mkbibpath_1(s, "bib", wflag) if r == nil
    return r
  end

end

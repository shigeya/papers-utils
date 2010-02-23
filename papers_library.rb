# Bibliography entry handler for Papers

require 'bib_library'

class PapersBibEntry < BibEntry
  def prep
    @article_type = :none
    @lines.each do |line|
      if line =~ /\s*([\w-]+)\s*=\s*(.*)$/
        l, r = $1, $2
        if l=~/keywords/ 
          if  r =~/specification/
            @article_type = :specification
          elsif l=~/keywords/ and r =~/site/
            @article_type = :site
          end
        end
      end
    end
    papers2bibtex
  end

  def out(o)
    o.puts "% " + "-"*(76 - @citekey.size) + " #{@citekey}"
    o.puts ""
    l, r = "", ""

    @lines.each do |line|
      if line =~ /\s*([\w-]+)\s*=\s*(.*)$/
        l, r = $1, $2
        pn = l.gsub(/\-/,"_").downcase
        begin
          l, r = eval("do_rec_#{pn}(l, r)")
        rescue NoMethodError
          # can't find processing lib
        end
        o.puts "  #{l} = #{r}"
      else
        o.puts line
      end
    end
    o.puts ""
  end

  def papers2bibtex 
    begin
      eval("do_#{tag}")
    rescue
      # can't find pre-processing func for a tag.
    end
  end


  ##
  ## Per record processing
  ##

  # If there are entries contain http://, quote it.
  def do_rec_note(l, r)
    r.gsub!(/\_/,"\\_")
    r.gsub!(/{(http:\/\/\S+)(.*)}/, '{\\url{\1}\2}')
    [l, r]
  end

  # Paper's note appear sometimes as "annote" instead of "note". Map this.
  def do_rec_annote(l, r)
    l.sub!(/annote/, "note")
    do_rec_note(l, r)
  end

  def do_rec_uri(l, r)
    r.gsub!(/\_/,"\\_")
    [l, r]
  end

  def do_rec_url(l, r)
    r.gsub!(/\_/,"\\_")
    r.gsub!(/{(.*)}/, '{\\url\&}')
    [l, r]
  end

  def do_rec_title(l, r)
    r.gsub!(/\{.*\}/, '{\&}')               # always quote it
    [l, r]
  end

  def do_rec_author(l, r)
    r.gsub!(@lib.keywords_re, '{\&}')
    [l, r]
  end

  def do_rec_journal(l, r)
    r.gsub!(@lib.keywords_re, '{\&}')
    [l, r]
  end

  ## * article
  ## 
  ## - Specification from LaTeX Companion:
  ## 
  ## article An article from a journal or magazine.
  ## 
  ## Required: author, title, journal, year.
  ## Optional: volume, number, pages, month, note

  def do_article
    # if it's a specification, force to @manual
    # if it's a site description, force to @misc
    # I couldn't determin condition whether output will be @manual or @article.
    if @article_type == :specification
      @lines.each {|l| l.sub!(/@article{/, "@manual{") }
      do_manual
    elsif @article_type == :site
      @lines.each {|l| l.sub!(/@article{/, "@misc{") }
      do_misc
    end
  end

  ## * manual
  def do_manual
  end

  ## * misc
  def do_misc
  end

  ## * inproceedings
  ## 
  ## - Specification from LaTeX Companion:
  ## 
  ## inproceedings An article in a conference proceedings.
  ## 
  ## Required: author, title, booktitle, year.
  ## Optional: editor, volume or number, series, pages, address, month,
  ## 	  organization, publisher, note.
  ## 
  ## 
  ## @inproceedings should use booktitle
  ## 
  ##     convert: journal -> booktitle 

  def do_inproceedings
    @lines.each {|l| l.sub!(/journal =/, "booktitle =") }
  end

  # OTHERs, including but not limited to:
  # manual, masterthesis, misc, phdthesis, techreport
  # book, inbook

end

class PapersBibLibrary < BibLibrary

  def new_bib(tag, citekey, lines)
    PapersBibEntry.new(self, tag, citekey, lines)
  end

  def postread
    self.each {|e| e.prep }
  end

end

# Bibliography entry handler for Papers

require 'bib_library'

class PapersBibEntry < BibEntry
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

  def do_rec_note(l, r)
    r.gsub!(/\_/,"\\_")
    [l, r]
  end

  def do_rec_uri(l, r)
    r.gsub!(/\_/,"\\_")
    [l, r]
  end

  def do_rec_url(l, r)
    do_rec_uri(l,r)
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
    PapersBibEntry.new(tag, citekey, lines)
  end

  def postread
    self.each {|e| e.papers2bibtex }
  end

end

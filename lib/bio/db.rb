#
#= bio/db.rb - DataBase parser general API
#
#   Copyright (C) 2001, 2002 KATAYAMA Toshiaki <k@bioruby.org>
#--
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
#--
#  $Id: db.rb,v 0.29 2005/10/23 07:16:29 nakao Exp $
#

require 'bio/sequence'
require 'bio/reference'
require 'bio/feature'

module Bio
  
  # Bio::DB API
  class DB

    def self.open(filename, *mode, &block)
      Bio::FlatFile.open(self, filename, *mode, &block)
    end

    def entry_id
      raise NotImplementedError
    end

    def tags
      @orig.keys
    end

    def exists?(tag)
      @orig.include?(tag)
    end

    def get(tag)
      @orig[tag]
    end

    def fetch(tag, skip = 0)
      field = @orig[tag].split(/\n/, skip + 1).last.to_s
      truncate(field.gsub(/^.{0,#{@tagsize}}/,''))
    end


    private

    def truncate(str)
      return str.gsub(/\s+/, ' ').strip
    end

    def tag_get(str)
      return str[0,@tagsize].strip
    end

    def tag_cut(str)
      str[0,@tagsize] = ''
      return str
    end

    def field_fetch(tag, skip = 0)
      unless @data[tag]
        @data[tag] = fetch(tag, skip)
      end
      return @data[tag]
    end

    def lines_fetch(tag) 
      unless @data[tag]  
        @data[tag] = get(tag).split(/\n/).map{ |l| tag_cut(l) }  
      end  
      @data[tag]  
    end 

  end

  # Bio::NCBIDB
  class NCBIDB < DB
    autoload :Common, 'bio/db/genbank/common'

    def initialize(entry, tagsize)
      @tagsize = tagsize
      @orig = entry2hash(entry.strip)	# Hash of the original entry
      @data = {}			# Hash of the parsed entry
    end


    private

    def toptag2array(str)
      sep = "\001"
      str.gsub(/\n([A-Za-z\/])/, "\n#{sep}\\1").split(sep)
    end

    def subtag2array(str)
      sep = "\001"
      str.gsub(/\n(\s{1,#{@tagsize-1}}\S)/, "\n#{sep}\\1").split(sep)
    end

    def entry2hash(entry)
      hash = Hash.new('')

      fields = toptag2array(entry)

      fields.each do |field|
        tag = tag_get(field)
        hash[tag] += field
      end
      return hash
    end

  end

  # Bio::KEGG
  class KEGGDB < NCBIDB
  end

  # Bio::EMBLDB
  class EMBLDB < DB
    autoload :Common, 'bio/db/embl/common'

    def initialize(entry, tagsize)
      @tagsize = tagsize
      @orig = entry2hash(entry.strip)	# Hash of the original entry
      @data = {}			# Hash of the parsed entry
    end

    private

    def entry2hash(entry)
      hash = Hash.new('')
      entry.each_line do |line|
        tag = tag_get(line)
        next if tag == 'XX'
        tag = 'R' if tag =~ /^R./	# Reference lines
        hash[tag] += line
      end
      return hash
    end

  end

end



=begin

= Bio::DB

* On-demand parsing and cache

The flatfile parsers (sub classes of the Bio::DB) split the original entry
into a Hash and store the hash in the @orig instance variable.  To parse
in detail is delayed until the method is called which requires a further
parsing of a content of the @orig hash.  Fully parsed data is cached in the
another hash, @data, separately.

== Class methods

--- Bio::DB.new(entry)

      This class method accepts the String of one entire entry and parse it to
      return the parsed database object.

== Object methods

--- Bio::DB#entry_id

      Returns an entry identifier as a String.  This method must be
      implemented in every database classes, so sub classes must override
      this method.

--- Bio::DB#tags

      Returns a list of the top level tags of the entry as an Array of a
      String.

--- Bio::DB#exists?(tag)

      Returns true or false - wether the entry contains the field of the tag.

--- Bio::DB#get(tag)

      Returns an intact field of the tag as a String.

--- Bio::DB#fetch(tag)

      Similar to the get method, however, fetch returns the content of the
      field without its tag and any extra white spaces stripped.

== Private/Protected methods

--- Bio::DB#truncate(str)

      Returns a String as extra white spaces removed.

--- Bio::DB#tag_get(str)

      Returns a tag name of the field as a String.

--- Bio::DB#tag_cut(str)

      Returns a String without a tag field.

--- Bio::DB#field_fetch(tag)

      Returns the content of the field as a String like the fetch method.
      Furthermore, field_fetch stores the result in the @data hash.

--- Bio::DB#lines_fetch(tag)

      Returns an Array containing each line of the field without a tag.
      lines_fetch also stores the result in the @data hash.

== For the sub class developpers

Every sub class should define the following constants if appropriate:

  * DELIMITER (RS)
    * entry separator of the flatfile of the database.
    * RS (= record separator) is a alias for the DELIMITER in short.

  * TAGSIZE
    * length of the tag field in the FORTRAN-like format.

        |<- tag field ->||<- data field                       ---->|
        ENTRY_ID         A12345
        DEFINITION       Hoge gene of the Pokemonia pikachuae

== Template of the sub class

  module Bio

    class Hoge < DB

      DELIMITER	= RS = "\n//\n"
      TAGSIZE	= 12		# You can omit this line if not needed

      def initialize(entry)
      end

      def entry_id
      end

    end

  end

== Recommended method names for sub classes

In general, the method name should be in the singular form when returns
a Object (including the case when the Object is a String), and should be
the plural form when returns same Objects in Array.  It depends on the
database classes that which form of the method name can be use.

For example, GenBank has several REFERENCE fields in one entry, so define
Bio::GenBank#references and this method should return an Array of the
Reference objects.  On the other hand, MEDLINE has one REFERENCE information
per one entry, so define Bio::MEDLINE#reference method and this should
return a Reference object.

The method names used in the sub classes should be taken from the following
list if appropriate:

--- entry_id	-> String

      The entry identifier.

--- definition	-> String

      The description of the entry.

--- reference	-> Bio::Reference
--- references	-> Array of Bio::Reference

      The reference field(s) of the entry.

--- dblink	-> String
--- dblinks	-> Array of String

      The link(s) to the other database entry.

--- naseq	-> Bio::Sequence::NA

      The DNA/RNA sequence of the entry.

--- nalen	-> Integer

      The length of the DNA/RNA sequence of the entry.

--- aaseq	-> Bio::Sequence::AA

      The amino acid sequence of the entry.

--- aalen	-> Integer

      The length of the amino acid sequence of the entry.

--- seq		-> Bio::Sequence::NA or Bio::Sequence::AA

      Returns an appropriate sequence object.

--- position	-> String

      The position of the sequence in the entry or in the genome (depends on
      the database).

--- locations	-> Bio::Locations

      Returns Bio::Locations.new(position).

--- division	-> String

      The sub division name of the database.

      * Example:
        * EST, VRL etc. for GenBank
        * PATTERN, RULE etc. for PROSITE

--- date	-> String

      The date of the entry.
      Should we use Date (by ParseDate) instead of String?

--- gene	-> String
--- genes	-> Array of String

      The name(s) of the gene.

--- organism	-> String

      The name of the organism.

= Bio::NCBIDB

Stores a NCBI style (GenBank, KEGG etc.) entry.

--- new(entry, tagsize)

      The entire entry is passed as a String.  The length of the tag field is
      passed as an Integer.  Parses the entry roughly by the entry2hash method
      and returns a database object.

== Private methods

--- toptag2array(str)

      Splits an entry into an Array of Strings at the level of top tags.

--- subtag2array(str)

      Splits a field into an Array of Strings at the level of sub tags.

--- entry2hash(str)

      Returns the contents of the entry as a Hash with the top level tags as
      its keys.

= Bio::KEGGDB

Inherits a NCBIDB class.

= Bio::EMBLDB

Stores an EMBL style (EMBL, TrEMBL, Swiss-Prot etc.) entry.

--- new(entry, tagsize)

      The entire entry is passed as a String.  The length of the tag field is
      passed as an Integer.  Parses the entry roughly by the entry2hash method
      and returns a database object.

== Private methods

--- entry2hash(str)

      Returns the contents of the entry as a Hash.

=end



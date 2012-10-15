# attributes : n|email|title|nickname|tel|bday|fn|org|note|uid
# todo change for another vcard managment class
module SimpleDav
  class Card
    class << self; attr_accessor :adb end
    @adb = nil

    def initialize(text = BASEVCF)
      @plain = text
      return self
    end

    def self.find(uid)
      where(:uid => uid)
    end

    # create address resource
    def self.create(params)
      @vcard = Card.new
      params.each do |k,v|
        @vcard.update_attribute(k,v)
      end
  
      headers = {
        "If-None-Match" => "*",
        "Content-Type" => "text/vcard",
        "Content-Length" => @vcard.to_s.size
        }
      uid = "#{adb.gen_uid}.vcf"
  
      @vcard.update_attribute(:uid, uid)
      if adb && adb.group
        @vcard.add_attribute("X-ADDRESSBOOKSERVER-MEMBER", "urn:uuid:#{adb.group}")
      end
  
      unc = adb.uri.clone
      unc.path += uid
      res = adb.client.request('PUT', unc, nil, @vcard.to_s, headers)

      if res.status < 200 or res.status >= 300
        @uid = nil
        raise "create failed: #{res.inspect}"
      else
        @uid = uid
      end
      @vcard
    end

    def update(params)
      params.each do |k,v|
        update_attribute(k,v)
      end
  
      headers = {
        "Content-Type" => "text/vcard",
        "Content-Length" => @plain.size
        }
      uid = self.uid
  
      unc = Card.adb.uri.clone
      unc.path += uid
      res = Card.adb.client.request('PUT', unc, nil, @plain, headers)

      if res.status < 200 or res.status >= 300
        @uid = nil
        raise "create failed: #{res.inspect}"
      else
        @uid = uid
      end
      self
    end

    def delete
      if @uid && Card.adb

        headers = {
          #"If-None-Match" => "*",
          "Content-Type" => "text/xml; charset=\"utf-8\""
          }
        unc = adb.uri.clone
        unc.path += @uid
        res = adb.client.request('DELETE', unc, nil, nil, headers)

        if res.status < 200 or res.status >= 300
          @uid = nil
          raise "delete failed: #{res.inspect}"
        else
          @uid = nil
          true
        end
      else
        raise "Failed : no connection or null id"
      end
    end

    def retreive
      path = "#{self.uid}.vcf"
      unc = adb.uri.clone
      unc.path += path
      res = adb.client.request('GET', unc)

      if res.status < 200 or res.status >= 300
        @uid = nil
        raise "delete failed: #{res.inspect}"
      else
        @plain = res.body
        @uid = uid
        true
      end
    end

    def update_attribute(a, v)
      @plain.match(/^#{a.to_s.upcase}:(.+)$/) ? @plain.gsub!(/^#{a.to_s.upcase}:(.+)$/, "#{a.to_s.upcase}:#{v}") : add_attribute(a, v)
    end

    def add_attribute(a, v)
      @plain["END:VCARD"] = "#{a.to_s.upcase}:#{v}\nEND:VCARD"
    end

    def method_missing(meth, *args, &block)
      case meth.to_s 
        when /^((n|email|title|nickname|tel|bday|fn|org|note|uid|X-ADDRESSBOOKSERVER-KIND)=?)$/
          run_on_field($1, *args, &block)
        when /^find_by_(.+)$/
          run_find_by_method($1, *args, &block)
      else
        super
      end
    end

    def run_on_field(attrs, *args, &block)
      field = attrs.upcase
      field["EMAIL"] = "EMAIL;TYPE=work" if field.match("EMAIL")

      if field =~ /=/
        field = field[0..-2]
        update_attribute(field, args)
      else
        if m = @plain.match(/#{field}:(.+)$/) 
          m[1]
        else
          nil
        end
      end
    end

      # find where RoR style
    def self.where(conditions)
      limit = nil #1
      query = Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
        xml.send('B:addressbook-query', 'xmlns:B' => "urn:ietf:params:xml:ns:carddav") do
          xml.send('A:prop', 'xmlns:A' => "DAV:") do
            xml.send('A:getetag')
            xml.send('B:address-data') 
        
          end
          #xml.send('C:filter', 'test' => "anyof") do
          xml.send('B:filter', 'test' => 'anyof') do
            conditions.each do |k,v|
              xml.send('B:prop-filter', 'test' => 'allof','name' => k.to_s) do
                #xml.send('C:text-match', 'collation' => "i;unicode-casemap", 'match-type' => "contains") do
                xml.send('B:text-match', 'collation' => "i;unicode-casemap", 'match-type' => "contains") do
                  xml << v
                end
              end
            end
          end
          if limit
            xml.send('C:limit') do
              xml.send('C:nresults') do
                xml << "#{limit}"
              end
            end
          end
        
        end

      end
      headers = {
        "content-Type" => "text/xml; charset=\"utf-8\"",
        "depth" => 1,
        "Content-Length" => "#{query.to_xml.to_s.size}"
        }
      content = adb.client.request('REPORT', adb.uri, nil, query.to_xml.to_s, headers)
      xml = Nokogiri::XML(content.body)
      vcards = []
      xml.xpath('//C:address-data').each do |card|
        vcards << Card.new(card.text)
      end
      return vcards
    end

    def run_find_by_method(attrs, *args, &block)
      attrs = attrs.split('_and_')
      attrs_with_args = [attrs, args].transpose
      conditions = Hash[attrs_with_args]
      where(conditions)
    end

    def to_s
      @plain.to_s
    end

  end
end
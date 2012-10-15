module SimpleDav
  class AddressBook < Base
    attr_reader :group
    def initialize(params)
      abu = "personal"
      @vcard = nil
      super(params)
      @abu = @type == "sogo" ? "Contacts/#{abu}/" : "#{abu}"
      @uri.path += @abu
      @group = nil #store group uid
      Card.adb = self
    end
  
    # select address book
    def change_group(abu)
      #todo select uid or nil if personnal
      # old style folders
      #@uri.path -= @abu
      #@uri.path += (@abu = abu)
      # new style v4 group
      groups = Card.where({"X-ADDRESSBOOKSERVER-KIND" => "group", "f" => abu})
      @group = groups && groups.first && groups.first.uid
    end
  
    # list available address books
    #find all X-ADDRESSBOOKSERVER-KIND
    def list(name)
      #Card.where("X-ADDRESSBOOKSERVER-KIND" => "group")
      if name
        query = Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
          #xml.send('B:addressbook-query', 'xmlns:B' => "urn:ietf:params:xml:ns:carddav") do
            xml.send('D:principal-property-search', 'xmlns:D' => "DAV:") do
              xml.send('D:property-search') do
                xml.send('D:prop') do
                  xml.send('D:displayname')
                end
                xml.send('D:match') do
                  xml << name
                end
              end
              xml.send('D:prop') do
                xml.send('C:addressbook-home-set', 'xmlns:C' => 'urn:ietf:params:xml:ns:carddav')
                xml.send('D:displayname')
              end
          
            end
          
          #end

        end
      else
        query = Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
          xml.send('A:propfind', 'xmlns:A' => 'DAV:') do
            xml.send('A:prop') do
              xml.send('D:addressbook-home-set', 'xmlns:D' => "urn:ietf:params:xml:ns:carddav")
              xml.send('D:directory-gateway', 'xmlns:D' => "urn:ietf:params:xml:ns:carddav")
              xml.send('A:displayname')
              xml.send('C:email-address-set', 'xmlns:C' => "http://calendarserver.org/ns/")
              xml.send('A:principal-collection-set')
              xml.send('A:principal-URL')
              xml.send('A:resource-id')
              xml.send('A:supported-report-set')
            end
          end
        end
      end
    
      headers = {
        "content-Type" => "text/xml; charset=\"utf-8\"",
        "depth" => 0,
        "brief" => "t",
        "Content-Length" => "#{query.to_xml.to_s.size}"
        }
      content = @client.request('REPORT', @uri, nil, query.to_xml.to_s, headers)
      puts content.body + "<<<<<\n\n"
      xml = Nokogiri::XML(content.body)
      vcards = []
      xml.xpath('//C:address-data').each do |card|
        vcards << Card.new(card.text)
      end
      return vcards
    end
  
    # find addresse resource by uid
    def self.find(uid)
      Card.find(self, uid)
    end
  
    # create collection : not working actually
    def create_folder(name, displayname = "", description = "")
      query = Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
        xml.send('D:mkcol', 'xmlns:D' => "DAV:", 'xmlns:C' => "urn:ietf:params:xml:ns:carddav") do
          xml.send('D:set') do
            xml.send('D:prop')
            xml.send('D:resourcetype') do
              xml.send('D:collection')
              xml.send('C:addressbook')
            end
          end
          xml.send('D:displayname') do
            xml << displayname
          end
          xml.send('C:addressbook-description', 'xml:lang' => "en") do
            xml << description
          end
        end
      end
    
      headers = {
        "content-Type" => "text/xml; charset=\"utf-8\"",
        "Content-Length" => query.to_xml.to_s.size
        }

      res = @client.request('MKCOL', @uri, nil, query.to_xml.to_s, headers)

      if res.status < 200 or res.status >= 300
        raise "create failed: #{res.inspect}"
      else
        true
      end
    end
  
    # create address book group
    def create(name, description = "")
      uid = "#{gen_uid}"
    
      @vcard = Card.new(GROUPVCF)
      @vcard.add_attribute("X-ADDRESSBOOKSERVER-KIND", "group")
      @vcard.add_attribute("rev", Time.now.utc.iso8601(2))
      @vcard.add_attribute("uid", uid)
      @vcard.add_attribute(:f, name)
      @vcard.add_attribute(:fn, description)
    
      headers = {
        "If-None-Match" => "*",
        "Content-Type" => "text/vcard",
        "Content-Length" => @vcard.to_s.size
        }
    
      unc = @uri.clone
      unc.path += "#{uid}.vcf"
      res = @client.request('PUT', unc, nil, @vcard.to_s, headers)

      if res.status < 200 or res.status >= 300
        @uid = nil
        raise "create failed: #{res.inspect}"
      else
        @uid = @group = uid
      end
      @vcard
    
    end
  
    # access to current vcard object
    def vcard
      @vcard
    end

    def debug_dev=(dev)
      @client.debug_dev = dev
    end

  end
end
# Author:: od (mailto:od@idfuze.com)
# Copyright:: 2012 IDFUZE.COM Olivier DIRRENBERGER - Released under the terms of the MIT license
# 
# This work is a part for PLUG&WORK project http://v4.myplugandwork.com
# 
# :title:SimpleDav

require 'uri'
require 'httpclient'
require 'nokogiri'
require 'logger'

BASEVCF = <<EOF
BEGIN:VCARD
PRODID:-//IDFuze//SimpleDav//EN
VERSION:3.0
CLASS:PUBLIC
PROFILE:VCARD
END:VCARD
EOF

GROUPVCF = BASEVCF

class SimpleDav
  attr_reader :headers, :uri, :client
  
  # generate unique id to create resources
  def gen_uid
    "#{rand(100000)}-#{Time.now.to_i}-#{rand(100000)}"
  end

  def initialize(params = {})
    begin
      url = params[:ssl] ? "https://#{params[:server]}/" : "http://#{params[:server]}/"
      url += case (@type = params[:type])
      when "sogo" then "SOGo/dav/#{params[:user]}/"
      else ""
      end
      @uri = URI.parse(url)
      @uid = nil
      @headers = {}
      #open(uri) if uri
      proxy = ENV['HTTP_PROXY'] || ENV['http_proxy'] || nil
      @client = HTTPClient.new(proxy)
      @client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE unless params[:verify]
      if (@user = params[:user]) && params[:pass]
        @client.set_basic_auth(@uri, @user, params[:pass])
      end
    rescue
      raise RuntimeError.exception("Init Failed!! (#{$!.to_s})")
    end
  end

end

class AddressBook < SimpleDav
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
  def list
    Card.where("X-ADDRESSBOOKSERVER-KIND" => "group")
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

# attributes : n|email|title|nickname|tel|bday|fn|org|note|uid
# todo change for another vcard managment class
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
      puts res.body
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
    limit = 1
    query = Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
      xml.send('B:addressbook-query', 'xmlns:B' => "urn:ietf:params:xml:ns:carddav") do
        xml.send('A:prop', 'xmlns:A' => "DAV:",) do
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
    puts ">>>> #{adb.uri}\n"
    content = adb.client.request('REPORT', adb.uri, nil, query.to_xml.to_s, headers)
    puts "#{content.body}\n\n#{query.to_xml}\n\n"
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

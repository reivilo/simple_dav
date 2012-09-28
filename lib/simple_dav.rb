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

class SimpleDav
  attr_reader :headers, :uri, :client
  
  def gen_uid
    "#{rand(100000)}-#{Time.now.to_i}-#{rand(100000)}"
  end

  def initialize(params = {})
    begin
      #https://serveur.ag-si.net/SOGo/dav/geraldine/Contacts/personal/
      url = params[:ssl] ? "https://#{params[:server]}/" : "http://#{params[:server]}/"
      url += case (@type = params[:type])
      when "sogo" then "/SOGo/dav/#{params[:user]}/"
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
  
  #PUT (Create) sends If-None-Match: *

#PUT (Replace) sends If-Match: <existing etag>

#DELETE sends If-Match: <existing etag>

  def initialize(abu = "personal", params)
    @vcard = nil
    super(params)
    abu = @type == "sogo" ? "Contacts/#{abu}/" : "#{abu}"
    @uri.path += abu
  end
  
  def self.find(uid)
    where(:uid => uid)
  end
  
  def create(params)
    Vcard.create(self, params)
  end
  
  def vcard
    @vcard
  end

  def where(conditions)
    query = Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
      xml.send('C:addressbook-query', 'xmlns:D' => "DAV:", 'xmlns:C' => "urn:ietf:params:xml:ns:carddav") do
        xml.send('D:prop') do
          xml.send('D:getetag')
          xml.send('C:address-data') do
            xml.send('C:prop', 'name' => "UID")
            conditions.each do |k,v|
              xml.send('C:prop', 'name' => k.to_s.upcase)
            end
          end
        end
        xml.send('C:filter') do
          conditions.each do |k,v|
            xml.send('C:prop-filter', 'name' => k.to_s.upcase) do
              xml.send('C:text-match', 'collation' => "i;unicode-casemap", 'match-type' => "equals") do
                xml << v
              end
            end
          end
        end
      end
    end
    headers = {
      "content-Type" => "text/xml; charset=\"utf-8\"",
      "depth" => 1
      }

    content = @client.request('REPORT', @uri, nil, query.to_xml.to_s, headers)
    #puts "#{content.body}"
    xml = Nokogiri::XML(content.body)
    vcards = []
    xml.xpath('//C:address-data').each do |card|
      vcards << Vcard.new(self, card.text)
    end
    return vcards
  end
  
  def update(params)
    #get card
    
    #push card with new params
  end
  
  def method_missing(meth, *args, &block)
    if meth.to_s =~ /^find_by_(.+)$/
      run_find_by_method($1, *args, &block)
    else
      super
    end
  end

  def run_find_by_method(attrs, *args, &block)
    attrs = attrs.split('_and_')
    attrs_with_args = [attrs, args].transpose
    conditions = Hash[attrs_with_args]
    where(conditions)
  end

  def debug_dev=(dev)
    @client.debug_dev = dev
  end

end

class Vcard
  attr_reader :ab
  
  def initialize(ab, text = BASEVCF)
    @plain = text
    @ab = ab
    return self
  end
  
  def self.create(ab, params)
    @vcard = Vcard.new(ab)

    params.each do |k,v|
      @vcard.update_attribute(k,v)
    end
    
    headers = {
      "If-None-Match" => "*",
      "Content-Type" => "text/vcard",
      "Content-Length" => @vcard.to_s.size
      }
    uid = "#{ab.gen_uid}.vcf"
    
    @vcard.update_attribute(:uid, uid)
    
    unc = ab.uri.clone
    unc.path += uid
    res = @vcard.ab.client.request('PUT', unc, nil, @vcard.to_s, headers)

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
    
    unc = ab.uri.clone
    unc.path += uid
    res = @ab.client.request('PUT', unc, nil, @plain, headers)

    if res.status < 200 or res.status >= 300
      @uid = nil
      raise "create failed: #{res.inspect}"
    else
      @uid = uid
    end
    self
  end
  
  def delete
    if @uid && @ab

      headers = {
        #"If-None-Match" => "*",
        "Content-Type" => "text/xml; charset=\"utf-8\""
        }
      unc = @ab.uri.clone
      unc.path += @uid
      res = @ab.client.request('DELETE', unc, nil, nil, headers)

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
  
  def update_attribute(a, v)
    @plain.match(/^#{a.to_s.upcase}:(.+)$/) ? @plain.gsub!(/^#{a.to_s.upcase}:(.+)$/, "#{a.to_s.upcase}:#{v}") : add_attribute(a, v)
  end
  
  def add_attribute(a, v)
    @plain["END:VCARD"] = "#{a.to_s.upcase}:#{v}\nEND:VCARD"
  end

  def method_missing(meth, *args, &block)
    if meth.to_s =~ /^((n|email|title|nickname|tel|bday|fn|org|note|uid)=?)$/
      run_on_field($1, *args, &block)
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
  
  def to_s
    @plain.to_s
  end
  
end

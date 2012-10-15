BASEVCF = <<EOF
BEGIN:VCARD
PRODID:-//IDFuze//SimpleDav//EN
VERSION:3.0
CLASS:PUBLIC
PROFILE:VCARD
END:VCARD
EOF

GROUPVCF = BASEVCF

module SimpleDav
  class Base
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

end
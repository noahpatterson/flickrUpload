require 'securerandom'
# require 'uri'
require 'cgi'
require 'base64'
require 'faraday'
require 'yaml'

@config = YAML::load(File.open('oauth_keys.yml'))

CONSUMER_KEY = @config.fetch("CONSUMER_KEY")
CONSUMER_SECRET = @config.fetch("CONSUMER_SECRET")

@flickrBaseURL = @config.fetch("flickrBaseURL")
@flickrRequestPath = @config.fetch("flickrRequestPath")
@flickrAuthorizationPath = @config.fetch("flickrAuthorizationPath")
@flickrAccessPath = @config.fetch("flickrAccessPath")
@flickrUploadPath = @config.fetch("flickrUploadPath")
@oAuthCallback = @config.fetch("oAuthCallback")
@oauthToken = @config.fetch("oauthToken")
@oauthTokenSecret = @config.fetch("oauthTokenSecret")
@oauthVerifier = @config.fetch("oauthVerifier")
@user_nsid = @config.fetch("user_nsid")


def key(token_secret)
  CGI.escape(CONSUMER_SECRET) + "&" + CGI.escape(token_secret)
end

def createCallParams
  {
    :oauth_nonce => "p3PDR7iMpzg",
    # nonce,
    :oauth_timestamp => 1390249102,
    # timeStamp,
    :oauth_consumer_key => CONSUMER_KEY,
    :oauth_signature_method => "HMAC-SHA1",
    :oauth_version => 1.0,
    :oauth_callback => @oAuthCallback
  }
end

def baseString(method, path, call_params)
  signature_params = call_params.map { |param, value| "#{param}=#{value.to_s}" }
  signature_string = signature_params.sort.join("&")
  method + "&" + CGI.escape(path) + "&" + CGI.escape(signature_string)
end

def nonce
  SecureRandom.hex()
end

def timeStamp
  Time.now.to_i
end

def sign( key, text )
  digest = OpenSSL::Digest::SHA1.new
  [OpenSSL::HMAC.digest(digest, key, text)].pack('m0').gsub(/\n$/,'')
end

def connection
  Faraday.new(:url => @flickrBaseURL) do |faraday|
    faraday.request  :url_encoded             # form-encode POST params
    faraday.response :logger                  # log requests to STDOUT
    faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
  end
end

def request_token
  conn = connection
  h = createCallParams
  base_string = baseString("GET", @flickrBaseURL + @flickrRequestPath, h)
  signature = sign(key(""), base_string)
  h[:oauth_signature] = signature
  conn.get @flickrRequestPath, h
end

def authorize
  res_hash = CGI.parse(request_token.body)
  @oauthToken = res_hash["oauth_token"][0]
  @oauthTokenSecret = res_hash["oauth_token_secret"][0]
  h = { :oauth_token => @oauthToken }
  conn = connection
  response = conn.get @flickrAuthorizationPath, h
  to_open = response.headers.fetch("location")
  `open #{to_open}`
  puts "Please type the 'oauth_verifier'"
  @oauthVerifier = gets.chomp
end

def access_token
  conn = connection
  h = createCallParams
  h[:oauth_verifier] = @oauthVerifier
  h[:oauth_token] = @oauthToken
  base_string = baseString("GET", @flickrBaseURL + @flickrAccessPath, h)
  signature = sign(key(@oauthTokenSecret), base_string)
  h[:oauth_signature] = signature
  res = conn.get @flickrAccessPath, h
  res_hash = CGI.parse(res.body)
  @oauthToken = res_hash["oauth_token"]
  @oauthTokenSecret = res_hash["oauth_token_secret"]
  @user_nsid =  res_hash["user_nsid"]
end

def storeNewTokens
  @config["oauthToken"] = @oauthToken
  @config["oauthTokenSecret"] = @oauthTokenSecret
  @config["oauthVerifier"] = @oauthVerifier
  @config["user_nsid"] = @user_nsid
  File.open("oauth_keys.yml", 'w') { |f| YAML.dump(@config, f) }
end
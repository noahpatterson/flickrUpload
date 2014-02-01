require 'csv'
require 'set'
require 'flickraw'
require 'yaml'
require 'cgi'
require_relative './ouath'

@config = YAML::load(File.open('oauth_keys.yml'))
@flickrAPIPath = @config.fetch("flickrAPIPath")
@flickrUploadPath = @config.fetch("flickrUploadPath")
@oauthTokenSecret = @config.fetch("oauthTokenSecret")
@oauthToken = @config.fetch("oauthToken")

def connection2
  Faraday.new(:url => @flickrUploadPath) do |faraday|
    faraday.request :multipart            # form-encode POST params
    faraday.response :logger                  # log requests to STDOUT
    faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
  end
end


def call(method, args)
  conn = connection
  h = createCallParams
  h[:method] =  method
  h[:nojsoncallback] = 1
  h[:format] = "json"
  h[:oauth_token] = @oauthToken
  h.merge!(args)
  base_string = baseString("GET", @flickrAPIPath, h)
  signature = sign(key(@oauthTokenSecret), base_string)
  h[:oauth_signature] = signature
  conn.get @flickrAPIPath, h
end

def upload(path, conn, args)
    h = createCallParams
    h[:oauth_token] = @oauthToken
    h.merge!(args)
    base_string = baseString("POST", @flickrUploadPath, h)
    signature = sign(key(@oauthTokenSecret), base_string)
    h[:oauth_signature] = signature
    #create a mfucking multipart....
    h[:photo] = Faraday::UploadIO.new(path, 'image/jpeg')
    conn.post @flickrUploadPath, h
  end

def allPhotoTitles
  res = call("flickr.photos.search", {:user_id => @user_nsid,:min_upload_date => "2012-01-01 12:00:00",:per_page => 500})
  resP = JSON.parse(res.body)
  resP.fetch("photos").fetch("photo").map {|photo| photo['title']}
end

class NewImages

  def self.findUserHome
    File.expand_path("~")
  end

  def self.createPathToPhotos(folder)
    findUserHome + "/Pictures/iPhoto\ Library.photolibrary/#{folder}/"
  end

  def self.allPhotosWithPath
    Dir.glob("/Volumes/mac/*")
  end

  def self.justPhotoName(path)
    path.match(/^(?:.*\/)(.*)\.(?:.*)$/)[1]
  end

  def self.newFilesNotSynced(synced)
    set = Set.new(synced)
    allPhotosWithPath.select { |path| set.include?(justPhotoName(path)) == false }
  end

  def self.updateSyncedImagesFile(newImages, syncedImages)
    newImages.each {|image| syncedImages << [justPhotoName(image)] }
  end

  def self.testOnePhoto
    newFilesNotSynced[0]
  end

  def self.progress
    1.upto(100) do |i|
      printf("\rPercentage: %d%", i)
      sleep(0.05)
    end
  end
end

#Net::HTTP.post_form





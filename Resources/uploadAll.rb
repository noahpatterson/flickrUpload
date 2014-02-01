require_relative './findIphotoImages'

flickrPhotos = allPhotoTitles
toSync = NewImages.newFilesNotSynced(flickrPhotos)

conn2 = connection2

toSync[0..199].each do |photo|
  upload(photo, conn2, {:async=>1})
end

# File attachments (screenshots) are stored on disk for now. The uploader and
# storage interface are the same ones we will use with S3 later, so switching
# is a config change rather than a rewrite.
Latch.configure do |settings|
  if LuckyEnv.test?
    settings.storages["cache"] = Latch::Storage::Memory.new
    settings.storages["store"] = Latch::Storage::Memory.new
  else
    settings.storages["cache"] = Latch::Storage::FileSystem.new(
      directory: "tmp",
      prefix: "latch-cache",
    )
    settings.storages["store"] = Latch::Storage::FileSystem.new(
      directory: "public",
      prefix: "media",
    )
  end

  settings.path_prefix = ":model/:id/:attachment"
end

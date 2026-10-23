# Scratch files for chunked uploads. They live in api/tmp, on the same
# filesystem as public/media, so the finished file is renamed into place
# instead of copied.
module UploadFiles
  DIRECTORY = "tmp/uploads"

  @@locks = {} of String => Mutex
  @@locks_guard = Mutex.new

  def self.part_path(token : String) : String
    File.join(DIRECTORY, "#{safe_token(token)}.part")
  end

  # Serialises the chunk writes of one upload. Two retries of the same chunk
  # must not both append their bytes.
  def self.lock(token : String) : Mutex
    @@locks_guard.synchronize { @@locks[token] ||= Mutex.new }
  end

  def self.create(token : String) : Nil
    Dir.mkdir_p(DIRECTORY)
    File.open(part_path(token), "w") { }
  end

  def self.delete(token : String) : Nil
    File.delete?(part_path(token))
  end

  def self.size(token : String) : Int64
    File.info?(part_path(token)).try(&.size) || 0_i64
  end

  def self.truncate(token : String, bytes : Int64) : Nil
    path = part_path(token)
    return unless File.exists?(path)

    File.open(path, "r+") { |file| file.truncate(bytes) }
  end

  private def self.safe_token(token : String) : String
    token.gsub(/[^A-Za-z0-9_-]/, "")
  end
end

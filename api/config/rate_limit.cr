# The in-memory store is enough for a single-process prototype. Replace it
# with Redis when the API runs as more than one process.
LuckyCache.configure do |settings|
  settings.storage = LuckyCache::MemoryStore.new
end

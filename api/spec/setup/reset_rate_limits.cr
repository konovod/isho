# Rate limit counters live in an in-memory cache shared by the whole spec
# process. Without this, the sixth request from the same IP in one action fails
# with 429 even though every example starts from a clean database.
Spec.before_each do
  LuckyCache.settings.storage.flush
end

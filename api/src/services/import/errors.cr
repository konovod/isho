# Failures of an import, split by what the worker should do about them.
module Import
  # The address or the answer is unusable: a bad link, a blocked host, a page
  # that is not HTML. Retrying will not help.
  class Failed < Exception; end

  # The page or the image is bigger than the limit. Also final.
  class TooLarge < Failed; end

  # The site is down or slow. The job is retried later.
  class Unavailable < Exception; end
end

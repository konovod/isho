# Removes Markdown images that were uploaded but never inserted into saved
# content. Projects, devlogs and forum posts keep their Markdown as text, so a
# file is "used" when any of those texts contains its URL.
#
#   ./bin/tasks db.cleanup_markdown_images             # dry run, 7 days
#   ./bin/tasks db.cleanup_markdown_images --days 30 --yes
class Db::CleanupMarkdownImages < LuckyTask::Task
  summary "Delete unreferenced Markdown images older than N days"

  arg days, "Only images older than this many days (default 7)", optional: true
  switch yes, "Actually delete the files and records (without this flag the task is a dry run)"

  DEFAULT_DAYS = 7

  def call
    retention = retention_days
    cutoff = Time.utc - retention.days
    images = MarkdownImageQuery.new.older_than(cutoff).results
    orphans = images.reject { |image| referenced?(image) }

    puts "Markdown images older than #{retention} days: #{images.size}"
    puts "Unreferenced: #{orphans.size}"

    unless yes?
      puts "Dry run. Re-run with --yes to delete #{orphans.size} image(s)."
      return
    end

    orphans.each do |image|
      MarkdownImage::DeleteOperation.delete!(image)
    end

    puts "Deleted #{orphans.size} image(s)."
  end

  private def retention_days : Int32
    value = days.try(&.strip)
    return DEFAULT_DAYS if value.nil? || value.empty?

    parsed = value.to_i?
    raise "Invalid --days value: #{value}" unless parsed && parsed.positive?

    parsed
  end

  private def referenced?(image : MarkdownImage) : Bool
    url = image.image.try(&.url)
    return false unless url

    pattern = "%#{url}%"

    return true if ProjectQuery.new.description.ilike(pattern).first?
    return true if DevlogQuery.new.body.ilike(pattern).first?
    return true if ForumPostQuery.new.body.ilike(pattern).first?
    return true if ForumPostQuery.new.quote_body.ilike(pattern).first?

    false
  end
end

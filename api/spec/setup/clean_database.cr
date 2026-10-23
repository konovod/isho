Spec.before_each do
  AppDatabase.truncate
  clean_upload_parts
end

# Finished and abandoned uploads keep their chunk file in api/tmp. The rows are
# truncated between examples, so the files would otherwise pile up after every
# spec run. After-each also covers the very last example.
Spec.after_each do
  clean_upload_parts
end

private def clean_upload_parts
  Dir.glob("#{UploadFiles::DIRECTORY}/*.part").each do |path|
    File.delete?(path)
  end
end

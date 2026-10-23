class SaveMarkdownImage < MarkdownImage::SaveOperation
  attach image, process: true
end

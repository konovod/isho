# An image uploaded from the Markdown editor. The URL is inserted into the
# project description, a devlog or a forum post as `![alt](url)`; the table
# keeps ownership and the stored file so uploads can be cleaned up later.
class MarkdownImage < BaseModel
  include Latch::Avram::Model

  table do
    belongs_to user : User
    attach image : MarkdownImageUploader::StoredFile?
  end
end

class DevlogSerializer < BaseSerializer
  def initialize(@devlog : Devlog)
  end

  def render
    {
      id:         @devlog.id,
      slug:       @devlog.slug,
      title:      @devlog.title,
      body:       @devlog.body,
      created_at: @devlog.created_at,
      updated_at: @devlog.updated_at,
    }
  end
end

module Api::V1::Forum::Params
  def current_page : Int32
    (params.get?(:page).try(&.to_i?) || 1).clamp(1, 10_000)
  end

  def page_size(default : Int32, max : Int32) : Int32
    (params.get?(:per_page).try(&.to_i?) || default).clamp(1, max)
  end

  def forum_topic_fields : Hash(String, String)
    params.nested?("forum_topic")
  end

  def forum_post_fields : Hash(String, String)
    params.nested?("forum_post")
  end

  def forum_topic_read_fields : Hash(String, String)
    params.nested?("forum_topic_read")
  end

  def forum_post_reaction_fields : Hash(String, String)
    params.nested?("forum_post_reaction")
  end

  def pagination_meta(page : Int32, per_page : Int32, total : Int64)
    pages = (total + per_page - 1) // per_page
    {page: page, per_page: per_page, total: total, pages: pages}
  end
end

class Api::V1::Forum::Sections::Index < ApiAction
  include Api::Auth::SkipRequireSession

  get "/api/v1/forum/sections" do
    sections = ForumSectionQuery.new.ordered.results
    user_id = current_user?.try(&.id)

    json({items: sections.map { |section| ForumSectionSerializer.new(section, user_id) }})
  end
end

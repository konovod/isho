class Api::V1::Admin::Forum::Sections::Index < ApiAction
  include Api::Auth::RequireAdmin

  get "/api/v1/admin/forum/sections" do
    sections = ForumSectionQuery.new.ordered.preload_parent.results

    json({items: sections.map { |section| AdminForumSectionSerializer.new(section) }})
  end
end

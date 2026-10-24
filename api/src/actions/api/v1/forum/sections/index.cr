class Api::V1::Forum::Sections::Index < ApiAction
  include Api::Auth::SkipRequireSession

  get "/api/v1/forum/sections" do
    sections = ForumSectionQuery.new.ordered.preload_parent.results

    json({items: sections.map { |section| ForumSectionSerializer.new(section, current_user?) }})
  end
end

class Api::V1::Forum::Sections::Index < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Forum::Blocks

  get "/api/v1/forum/sections" do
    sections = ForumSectionQuery.new.ordered.preload_parent.results

    json({
      items: sections.map { |section|
        ForumSectionSerializer.new(section, current_user?, forum_blocked_ids)
      },
    })
  end
end

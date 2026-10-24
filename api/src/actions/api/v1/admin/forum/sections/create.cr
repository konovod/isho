class Api::V1::Admin::Forum::Sections::Create < ApiAction
  include Api::Auth::RequireAdmin

  post "/api/v1/admin/forum/sections" do
    section = SaveForumSection.create!(params)

    json AdminForumSectionSerializer.new(reload_section(section)), status: 201
  end

  private def reload_section(section : ForumSection) : ForumSection
    ForumSectionQuery.new.id(section.id).preload_parent.first? || section
  end
end

class Api::V1::Admin::Forum::Sections::Update < ApiAction
  include Api::Auth::RequireAdmin

  patch "/api/v1/admin/forum/sections/:id" do
    section = find_forum_section!
    updated = SaveForumSection.update!(section, params)

    json AdminForumSectionSerializer.new(reload_section(updated))
  end

  private def find_forum_section! : ForumSection
    ForumSectionQuery.new.id(params.get(:id)).preload_parent.first? ||
      raise Avram::RecordNotFoundError.new(ForumSection.table_name, params.get(:id).to_s)
  end

  private def reload_section(section : ForumSection) : ForumSection
    ForumSectionQuery.new.id(section.id).preload_parent.first? || section
  end
end

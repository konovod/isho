class Api::V1::Admin::Forum::Sections::Update < ApiAction
  include Api::Auth::RequireAdmin

  patch "/api/v1/admin/forum/sections/:id" do
    section = find_forum_section!
    updated = SaveForumSection.update!(section, params)

    json AdminForumSectionSerializer.new(updated)
  end

  private def find_forum_section! : ForumSection
    ForumSectionQuery.new.id(params.get(:id)).first? ||
      raise Avram::RecordNotFoundError.new(ForumSection.table_name, params.get(:id).to_s)
  end
end

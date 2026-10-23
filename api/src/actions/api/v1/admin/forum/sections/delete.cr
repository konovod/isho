class Api::V1::Admin::Forum::Sections::Delete < ApiAction
  include Api::Auth::RequireAdmin

  delete "/api/v1/admin/forum/sections/:id" do
    section = find_forum_section!

    if section.slug == "projects"
      json ErrorSerializer.new(
        code: "protected_section",
        message: "Раздел обсуждений проектов удалить нельзя",
      ), status: 422
    elsif ForumTopicQuery.new.section_id(section.id).select_count > 0
      json ErrorSerializer.new(
        code: "section_not_empty",
        message: "В разделе есть темы — удалить можно только пустой раздел",
      ), status: 422
    else
      ForumSection::DeleteOperation.delete!(section)
      head 204
    end
  end

  private def find_forum_section! : ForumSection
    ForumSectionQuery.new.id(params.get(:id)).first? ||
      raise Avram::RecordNotFoundError.new(ForumSection.table_name, params.get(:id).to_s)
  end
end

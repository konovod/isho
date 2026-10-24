class Api::V1::Admin::Forum::Sections::Delete < ApiAction
  include Api::Auth::RequireAdmin

  PROTECTED_SLUGS = %w[projects jams]

  delete "/api/v1/admin/forum/sections/:id" do
    section = find_forum_section!

    if PROTECTED_SLUGS.includes?(section.slug)
      json ErrorSerializer.new(
        code: "protected_section",
        message: "Этот раздел удалить нельзя",
      ), status: 422
    elsif ForumSectionQuery.new.children_of(section.id).select_count > 0
      json ErrorSerializer.new(
        code: "section_has_children",
        message: "В разделе есть подразделы — сначала удалите или перенесите их",
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

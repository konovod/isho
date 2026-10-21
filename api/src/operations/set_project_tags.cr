class SetProjectTags < Avram::Operation
  needs project : Project
  needs tag_slugs : Array(String)

  def run
    ProjectTagQuery.new.project_id(project.id).delete

    slugs = tag_slugs.map(&.strip.downcase).reject(&.empty?).uniq.first(8)
    TagQuery.new.slug.in(slugs).results.each do |tag|
      ProjectTag::SaveOperation.create!(project_id: project.id, tag_id: tag.id)
    end
  end
end

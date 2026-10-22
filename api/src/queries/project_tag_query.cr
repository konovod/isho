class ProjectTagQuery < ProjectTag::BaseQuery
  # Tag popularity is counted for the public catalogue only, so drafts must
  # not inflate the numbers.
  def with_published_project
    join_project(ProjectQuery.new.published)
  end
end

class ProjectTagQuery < ProjectTag::BaseQuery
  # Tag popularity is counted for the catalogue the viewer can actually see:
  # drafts and content hidden by the viewer's preferences must not inflate it.
  def with_visible_project(viewer : User?)
    join_project(ProjectQuery.new.visible_to(viewer))
  end
end

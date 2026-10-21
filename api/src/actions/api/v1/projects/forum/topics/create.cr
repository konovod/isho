class Api::V1::Projects::Forum::Topics::Create < ApiAction
  include Api::V1::Projects::ProjectParams
  include Api::V1::Forum::Params
  include Api::V1::Forum::Lookup
  include Api::Auth::RequireConfirmedEmail

  post "/api/v1/projects/:slug/forum/topics" do
    unless project_visible?
      raise Avram::RecordNotFoundError.new(Project.table_name, params.get(:slug).to_s)
    end

    section = find_forum_section!("projects")
    fields = forum_topic_fields

    topic = CreateForumTopic.run!(
      section: section,
      user: current_user,
      project: project,
      title: fields["title"]? || "",
      body: fields["body"]? || "",
    )

    json ForumTopicSerializer.new(reload_forum_topic(topic)), status: 201
  end
end

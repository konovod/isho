class Api::V1::Forum::Topics::Create < ApiAction
  include Api::V1::Forum::Params
  include Api::V1::Forum::Lookup
  include Api::Auth::RequireConfirmedEmail

  post "/api/v1/forum/sections/:section_slug/topics" do
    section = find_forum_section!(params.get(:section_slug))
    raise Api::ForbiddenError.new if section.slug == "projects"

    fields = forum_topic_fields

    topic = CreateForumTopic.run!(
      section: section,
      user: current_user,
      project: nil,
      title: fields["title"]? || "",
      body: fields["body"]? || "",
    )

    json ForumTopicSerializer.new(reload_forum_topic(topic)), status: 201
  end
end

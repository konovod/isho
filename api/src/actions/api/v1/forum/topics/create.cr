class Api::V1::Forum::Topics::Create < ApiAction
  include Api::V1::Forum::Params
  include Api::V1::Forum::Lookup
  include Api::Auth::RequireConfirmedEmail
  include Api::Auth::RequireNotBanned

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

    # The answer is generated later by the worker: the author must not wait
    # for the model, and a retried request must not create a second topic.
    answer = nil
    if fields["request_ai_answer"]? == "true"
      begin
        answer = Ai::ForumAnswer.enqueue(topic, current_user, section)
      rescue
        # The topic is already saved. A failed enqueue must not turn a created
        # topic into a 500 and invite a retry that duplicates it.
        answer = nil
      end
    end

    json ForumTopicSerializer.new(reload_forum_topic(topic), ai_answer: answer), status: 201
  end
end

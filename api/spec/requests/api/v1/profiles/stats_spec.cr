require "../../../../spec_helper"

describe "GET /api/v1/users/:username stats" do
  it "counts published projects, forum messages and likes" do
    author = UserFactory.create
    ProjectFactory.create &.user_id(author.id).status("published").published_at(Time.utc)
    ProjectFactory.create &.user_id(author.id)

    section = ForumSectionFactory.create
    topic = ForumTopicFactory.create &.section_id(section.id)
    author_post = ForumPostFactory.create &.topic_id(topic.id).user_id(author.id)
    other_post = ForumPostFactory.create &.topic_id(topic.id)

    ForumPostReactionFactory.create &.post_id(author_post.id).user_id(UserFactory.create.id)
    ForumPostReactionFactory.create &.post_id(author_post.id).user_id(UserFactory.create.id)
    ForumPostReactionFactory.create &.post_id(author_post.id).user_id(UserFactory.create.id).kind("dislike")

    # The author gave one like and one dislike: only the like is counted.
    ForumPostReactionFactory.create &.post_id(other_post.id).user_id(author.id)
    dislikes_given = ForumPostFactory.create &.topic_id(topic.id)
    ForumPostReactionFactory.create &.post_id(dislikes_given.id).user_id(author.id).kind("dislike")

    response = ApiClient.new.get("/api/v1/users/#{author.username}")

    response.status_code.should eq 200
    stats = JSON.parse(response.body)["stats"]
    stats["projects_count"].as_i.should eq 1
    stats["comments_count"].as_i.should eq 1
    stats["likes_given_count"].as_i.should eq 1
    # Two likes minus one dislike on the author's only message.
    stats["likes_received_count"].as_i.should eq 1
  end

  it "hides adult projects and their forum activity from visitors" do
    author = UserFactory.create
    ProjectFactory.create &.user_id(author.id).status("published").published_at(Time.utc)
    hidden = ProjectFactory.create &.user_id(author.id).status("published").published_at(Time.utc).nsfw(true)

    projects_section = ForumSectionFactory.create &.slug("projects")
    hidden_topic = ForumTopicFactory.create &.section_id(projects_section.id).project_id(hidden.id)
    hidden_post = ForumPostFactory.create &.topic_id(hidden_topic.id).user_id(author.id)
    ForumPostReactionFactory.create &.post_id(hidden_post.id).user_id(UserFactory.create.id)

    open_section = ForumSectionFactory.create
    open_topic = ForumTopicFactory.create &.section_id(open_section.id)
    open_post = ForumPostFactory.create &.topic_id(open_topic.id).user_id(author.id)
    ForumPostReactionFactory.create &.post_id(open_post.id).user_id(UserFactory.create.id)

    guest = JSON.parse(ApiClient.new.get("/api/v1/users/#{author.username}").body)["stats"]
    guest["projects_count"].as_i.should eq 1
    guest["comments_count"].as_i.should eq 1
    guest["likes_received_count"].as_i.should eq 1

    reader = AuthHelper.client_for(UserFactory.create)
    seen = JSON.parse(reader.get("/api/v1/users/#{author.username}").body)["stats"]
    seen["projects_count"].as_i.should eq 2
    seen["comments_count"].as_i.should eq 2
    seen["likes_received_count"].as_i.should eq 2
  end

  it "keeps the received score negative when dislikes outweigh likes" do
    author = UserFactory.create
    post = ForumPostFactory.create &.user_id(author.id)
    ForumPostReactionFactory.create &.post_id(post.id).user_id(UserFactory.create.id)
    ForumPostReactionFactory.create &.post_id(post.id).user_id(UserFactory.create.id).kind("dislike")
    ForumPostReactionFactory.create &.post_id(post.id).user_id(UserFactory.create.id).kind("dislike")

    stats = JSON.parse(ApiClient.new.get("/api/v1/users/#{author.username}").body)["stats"]

    stats["likes_received_count"].as_i.should eq -1
  end
end

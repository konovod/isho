require "../../../../spec_helper"

describe "Forum post reactions" do
  describe "POST /api/v1/forum/posts/:id/reactions" do
    it "adds a like and removes it on the second click" do
      author = UserFactory.create
      voter = UserFactory.create
      post = ForumPostFactory.create &.user_id(author.id)
      client = AuthHelper.client_for(voter)

      liked = client.post("/api/v1/forum/posts/#{post.id}/reactions", forum_post_reaction: {
        kind: "like",
      })

      liked.status_code.should eq 200
      body = JSON.parse(liked.body)["reactions"]
      body["likes_count"].as_i.should eq 1
      body["dislikes_count"].as_i.should eq 0
      body["my_reaction"].as_s.should eq "like"

      unliked = client.post("/api/v1/forum/posts/#{post.id}/reactions", forum_post_reaction: {
        kind: "like",
      })

      body = JSON.parse(unliked.body)["reactions"]
      body["likes_count"].as_i.should eq 0
      body["my_reaction"].as_nil.should be_nil
      ForumPostReactionQuery.new.for_post(post.id).select_count.should eq 0
    end

    it "switches a like to a dislike" do
      author = UserFactory.create
      voter = UserFactory.create
      post = ForumPostFactory.create &.user_id(author.id)
      client = AuthHelper.client_for(voter)

      client.post("/api/v1/forum/posts/#{post.id}/reactions", forum_post_reaction: {kind: "like"})
      response = client.post("/api/v1/forum/posts/#{post.id}/reactions", forum_post_reaction: {kind: "dislike"})

      body = JSON.parse(response.body)["reactions"]
      body["likes_count"].as_i.should eq 0
      body["dislikes_count"].as_i.should eq 1
      body["my_reaction"].as_s.should eq "dislike"
      ForumPostReactionQuery.new.for_post(post.id).select_count.should eq 1
    end

    it "does not let the author vote for the own message" do
      author = UserFactory.create
      post = ForumPostFactory.create &.user_id(author.id)

      response = AuthHelper.client_for(author).post(
        "/api/v1/forum/posts/#{post.id}/reactions",
        forum_post_reaction: {kind: "like"},
      )

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "own_post"
      ForumPostReactionQuery.new.for_post(post.id).select_count.should eq 0
    end

    it "rejects an unknown kind" do
      voter = UserFactory.create
      post = ForumPostFactory.create

      response = AuthHelper.client_for(voter).post(
        "/api/v1/forum/posts/#{post.id}/reactions",
        forum_post_reaction: {kind: "love"},
      )

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["kind"].as_a.first.as_s.should eq "is invalid"
    end

    it "requires authentication" do
      post = ForumPostFactory.create

      response = ApiClient.new.post("/api/v1/forum/posts/#{post.id}/reactions", forum_post_reaction: {
        kind: "like",
      })

      response.status_code.should eq 401
    end

    it "rejects a banned user" do
      admin = UserFactory.create &.is_admin(true)
      voter = UserFactory.create
      post = ForumPostFactory.create
      BanUser.run!(user: voter, moderator: admin, reason: "Спам", days: 3)

      response = AuthHelper.client_for(voter).post(
        "/api/v1/forum/posts/#{post.id}/reactions",
        forum_post_reaction: {kind: "like"},
      )

      response.status_code.should eq 403
      JSON.parse(response.body)["error"]["code"].as_s.should eq "user_banned"
    end
  end

  describe "reactions in the topic payload" do
    it "shows counts to everyone and the reader's own vote only to the reader" do
      author = UserFactory.create
      voter = UserFactory.create
      section = ForumSectionFactory.create
      topic = ForumTopicFactory.create &.section_id(section.id)
      post = ForumPostFactory.create &.topic_id(topic.id).user_id(author.id)
      ForumPostReactionFactory.create &.post_id(post.id).user_id(voter.id)

      path = "/api/v1/forum/sections/#{section.slug}/topics/#{topic.slug}"

      guest_item = JSON.parse(ApiClient.new.get(path).body)["items"].as_a.first
      guest_item["reactions"]["likes_count"].as_i.should eq 1
      guest_item["reactions"]["my_reaction"].as_nil.should be_nil

      reader_item = JSON.parse(AuthHelper.client_for(voter).get(path).body)["items"].as_a.first
      reader_item["reactions"]["likes_count"].as_i.should eq 1
      reader_item["reactions"]["my_reaction"].as_s.should eq "like"
    end

    it "drops the count when a voter is deleted" do
      author = UserFactory.create
      voter = UserFactory.create
      section = ForumSectionFactory.create
      topic = ForumTopicFactory.create &.section_id(section.id)
      post = ForumPostFactory.create &.topic_id(topic.id).user_id(author.id)
      ForumPostReactionFactory.create &.post_id(post.id).user_id(voter.id)

      DeleteUserAccount.run!(user: voter)

      body = JSON.parse(ApiClient.new.get("/api/v1/forum/sections/#{section.slug}/topics/#{topic.slug}").body)
      body["items"].as_a.first["reactions"]["likes_count"].as_i.should eq 0
    end
  end

  describe "GET /api/v1/forum/posts/:id/reactions" do
    it "returns the latest ten voters and marks the list as truncated" do
      author = UserFactory.create
      post = ForumPostFactory.create &.user_id(author.id)
      voters = [] of User

      12.times do |index|
        voter = UserFactory.create
        voters << voter
        ForumPostReactionFactory.create &.post_id(post.id).user_id(voter.id).created_at(Time.utc - (12 - index).minutes)
      end

      response = ApiClient.new.get("/api/v1/forum/posts/#{post.id}/reactions?kind=like")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["kind"].as_s.should eq "like"
      body["total"].as_i.should eq 12
      body["truncated"].as_bool.should be_true
      body["items"].as_a.size.should eq 10
      body["items"].as_a.first["username"].as_s.should eq voters.last.username
    end

    it "returns an empty list for a post without votes" do
      post = ForumPostFactory.create

      response = ApiClient.new.get("/api/v1/forum/posts/#{post.id}/reactions?kind=dislike")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["total"].as_i.should eq 0
      body["truncated"].as_bool.should be_false
      body["items"].as_a.should be_empty
    end

    it "rejects an unknown kind" do
      post = ForumPostFactory.create

      ApiClient.new.get("/api/v1/forum/posts/#{post.id}/reactions?kind=love").status_code.should eq 422
    end
  end
end

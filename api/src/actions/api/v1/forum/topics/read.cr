class Api::V1::Forum::Topics::Read < ApiAction
  include Api::V1::Forum::Params
  include Api::V1::Forum::Lookup
  include Api::V1::Forum::Visibility

  post "/api/v1/forum/topics/:id/read" do
    topic = find_forum_topic!(params.get(:id))
    require_visible_forum_topic!(topic)

    last_post_id = forum_topic_read_fields["last_post_id"]?.try(&.to_i64?)
    unless last_post_id
      return json(ErrorSerializer.new(
        code: "validation_failed",
        message: "Укажите последнее прочитанное сообщение.",
        details: {"last_post_id" => ["is required"]},
      ), status: 422)
    end

    last_post = ForumPostQuery.new
      .for_topic(topic.id)
      .id(last_post_id)
      .first?

    unless last_post
      return json(ErrorSerializer.new(
        code: "validation_failed",
        message: "Сообщение не найдено в этой теме.",
        details: {"last_post_id" => ["is invalid"]},
      ), status: 422)
    end

    # Posts are shown chronologically, and their ids grow in the same order.
    read_count = ForumPostQuery.new
      .for_topic(topic.id)
      .where("forum_posts.id <= ?", last_post.id)
      .select_count
      .to_i32

    read = ForumTopicReadQuery.new
      .for_user(current_user.id)
      .for_topic(topic.id)
      .first?

    # The marker never goes back. A row written before `last_post_id` existed
    # is treated as read up to the post its count points at.
    newer = read.nil? ||
            read.last_post_id.nil? ||
            last_post.id > read.last_post_id.not_nil!

    read = if read
             newer ? SaveForumTopicRead.update!(read, read_count: read_count, last_post_id: last_post.id) : read
           else
             SaveForumTopicRead.create!(
               user_id: current_user.id,
               topic_id: topic.id,
               read_count: read_count,
               last_post_id: last_post.id,
             )
           end

    unread = if forum_blocks?
               ForumReadState.for_topics([topic.id], current_user.id)[topic.id].unread_count
             else
               remaining = topic.total_posts - read.read_count
               remaining.positive? ? remaining : 0
             end

    json({
      read_posts_count: read.read_count,
      unread_count:     unread,
    })
  end
end

class ForumPostSerializer < BaseSerializer
  def initialize(
    @post : ForumPost,
    @quote_page : Int32? = nil,
    @reactions : ForumReactions::Summary = ForumReactions::Summary.empty,
    @blocked_usernames : Array(String) = [] of String,
  )
  end

  def render
    {
      id:         @post.id,
      body:       @post.body,
      author:     UserSerializer.new(@post.user),
      created_at: @post.created_at,
      updated_at: @post.updated_at,
      edited:     edited?,
      quote:      quote,
      reactions:  ForumPostReactionsSerializer.new(@reactions).render,
    }
  end

  private def edited? : Bool
    @post.updated_at > @post.created_at
  end

  private def quote
    return nil unless @post.quoted?
    # A quote keeps a snapshot rather than a user id, so the username is the
    # only way to hide words of a blocked author inside somebody else's post.
    return nil if @blocked_usernames.includes?(@post.quote_author_username.to_s)

    {
      post_id:         @post.quoted_post_id,
      page:            @quote_page,
      author_name:     @post.quote_author_name,
      author_username: @post.quote_author_username,
      body:            @post.quote_body,
    }
  end
end

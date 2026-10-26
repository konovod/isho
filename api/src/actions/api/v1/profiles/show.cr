class Api::V1::Profiles::Show < ApiAction
  include Api::Auth::SkipRequireSession

  get "/api/v1/users/:username" do
    user = UserQuery.new.username(params.get(:username)).first? ||
           raise Avram::RecordNotFoundError.new(User.table_name, params.get(:username).to_s)

    projects = ProjectQuery.new
      .visible_to(current_user?)
      .for_user(user.id)
      .newest
      .preload_user
      .preload_screenshots
      .preload_tags
      .preload_builds
      .limit(AppSettings::PROJECTS_PER_PAGE)
      .results

    # Only the blocker learns about the block; the blocked account always sees
    # the same profile as before.
    blocked = current_user?.try { |viewer|
      !UserBlockQuery.new.blocker(viewer.id).blocked_user(user.id).first?.nil?
    } || false

    # The response depends on the viewer (hidden projects, the personal
    # `blocked` flag), so a shared cache must never store it.
    context.response.headers["Cache-Control"] = "private, no-store"

    json({
      user:     UserSerializer.new(user),
      stats:    ProfileStatsSerializer.new(ProfileStats.for_user(user, current_user?)),
      projects: projects.map { |project| ProjectSerializer.new(project) },
      blocked:  blocked,
    })
  end
end

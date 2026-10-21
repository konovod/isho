class Api::V1::Profiles::Show < ApiAction
  include Api::Auth::SkipRequireSession

  get "/api/v1/users/:username" do
    user = UserQuery.new.username(params.get(:username)).first? ||
           raise Avram::RecordNotFoundError.new(User.table_name, params.get(:username).to_s)

    projects = ProjectQuery.new
      .published
      .for_user(user.id)
      .newest
      .preload_user
      .preload_screenshots
      .preload_tags
      .limit(AppSettings::PROJECTS_PER_PAGE)
      .results

    json({
      user:     UserSerializer.new(user),
      projects: projects.map { |project| ProjectSerializer.new(project) },
    })
  end
end

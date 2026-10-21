class Api::V1::Admin::Users::Index < ApiAction
  include Api::Auth::RequireAdmin

  get "/api/v1/admin/users" do
    page = (params.get?(:page).try(&.to_i?) || 1).clamp(1, 10_000)
    per_page = (params.get?(:per_page).try(&.to_i?) || 24).clamp(1, 100)

    query = UserQuery.new.created_at.desc_order

    if term = params.get?(:q).try(&.strip)
      query = query.search(term) unless term.empty?
    end

    total = query.clone.select_count
    users = query
      .limit(per_page)
      .offset((page - 1) * per_page)
      .results

    json({
      items: users.map { |user| AdminUserSerializer.new(user, ProjectQuery.new.for_user(user.id).select_count) },
      meta:  {page: page, per_page: per_page, total: total},
    })
  end
end

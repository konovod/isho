class Api::V1::Admin::BlockedEmails::Index < ApiAction
  include Api::Auth::RequireAdmin

  get "/api/v1/admin/blocked_emails" do
    page = (params.get?(:page).try(&.to_i?) || 1).clamp(1, 10_000)
    per_page = (params.get?(:per_page).try(&.to_i?) || 24).clamp(1, 100)

    query = BlockedEmailQuery.new.newest_first

    if term = params.get?(:q).try(&.strip)
      query = query.search(term) unless term.empty?
    end

    total = query.clone.select_count
    entries = query
      .limit(per_page)
      .offset((page - 1) * per_page)
      .results

    json({
      items: BlockedEmailSerializer.for_collection(entries),
      meta:  {page: page, per_page: per_page, total: total},
    })
  end
end

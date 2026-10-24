class Api::V1::Jams::Publish < ApiAction
  include Api::V1::Jams::RequireOwner
  include Api::Auth::RequireConfirmedEmail

  post "/api/v1/jams/:slug/publish" do
    if jam.published?
      return json ErrorSerializer.new(
        code: "jam_already_published",
        message: "Джем уже опубликован",
      ), status: 422
    end

    if jam.canceled?
      return json ErrorSerializer.new(
        code: "jam_canceled",
        message: "Отменённый джем нельзя опубликовать",
      ), status: 422
    end

    details = {} of String => Array(String)

    details["starts_at"] = ["is required"] unless jam.starts_at
    details["submissions_close_at"] = ["is required"] unless jam.submissions_close_at
    details["voting_closes_at"] = ["is required"] unless jam.voting_closes_at

    if starts_at = jam.starts_at
      if closes_at = jam.submissions_close_at
        details["submissions_close_at"] = ["must be after the start"] if starts_at >= closes_at
      end
    end

    if closes_at = jam.submissions_close_at
      if voting_closes_at = jam.voting_closes_at
        details["voting_closes_at"] = ["must be after submissions close"] if closes_at >= voting_closes_at
      end
    end

    if JamCriterionQuery.new.for_jam(jam.id).select_count.zero?
      details["criteria"] = ["at least one criterion is required"]
    end

    unless details.empty?
      return json ErrorSerializer.new(
        code: "jam_not_ready",
        message: "Заполните даты и добавьте хотя бы один критерий",
        details: details,
      ), status: 422
    end

    PublishJam.run!(jam: jam)

    json JamSerializer.new(reload_jam(jam), current_user?, detailed: true)
  end
end

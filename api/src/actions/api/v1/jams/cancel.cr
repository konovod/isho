class Api::V1::Jams::Cancel < ApiAction
  include Api::V1::Jams::RequireOwner
  include Api::Auth::RequireConfirmedEmail

  post "/api/v1/jams/:slug/cancel" do
    if jam.canceled?
      return json ErrorSerializer.new(
        code: "jam_canceled",
        message: "Джем уже отменён",
      ), status: 422
    end

    fields = params.nested?("jam")
    reason = fields["cancel_reason"]?.to_s.strip

    if reason.nil? || reason.empty?
      return json ErrorSerializer.new(
        code: "validation_failed",
        message: "Укажите причину отмены",
        details: {"cancel_reason" => ["is required"]},
      ), status: 422
    end

    if reason.size > 500
      return json ErrorSerializer.new(
        code: "validation_failed",
        message: "Причина отмены слишком длинная",
        details: {"cancel_reason" => ["is too long"]},
      ), status: 422
    end

    CancelJam.run!(jam: jam, reason: reason)

    json JamSerializer.new(reload_jam(jam), current_user?, detailed: true)
  end
end

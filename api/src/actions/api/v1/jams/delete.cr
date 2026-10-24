class Api::V1::Jams::Delete < ApiAction
  include Api::V1::Jams::RequireOwner

  delete "/api/v1/jams/:slug" do
    unless jam.draft?
      return json ErrorSerializer.new(
        code: "jam_not_draft",
        message: "Удалить можно только черновик; опубликованный джем отменяют",
      ), status: 422
    end

    DeleteJam.run!(jam: jam)
    head 204
  end
end

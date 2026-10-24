class Api::V1::Jams::Show < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Jams::JamParams

  get "/api/v1/jams/:slug" do
    unless jam_visible?
      raise Avram::RecordNotFoundError.new(Jam.table_name, params.get(:slug).to_s)
    end

    json JamSerializer.new(jam, current_user?, detailed: true)
  end
end

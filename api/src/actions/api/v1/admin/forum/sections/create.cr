class Api::V1::Admin::Forum::Sections::Create < ApiAction
  include Api::Auth::RequireAdmin

  post "/api/v1/admin/forum/sections" do
    section = SaveForumSection.create!(params)

    json AdminForumSectionSerializer.new(section), status: 201
  end
end

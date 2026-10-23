class Api::V1::Me::Storage::Show < ApiAction
  get "/api/v1/me/storage" do
    json StorageSerializer.new(
      StorageUsage.for_user(current_user.id),
      StorageUsage.per_project(current_user.id),
      StorageUsage.server_total,
      DiskSpace.available_bytes,
    )
  end
end

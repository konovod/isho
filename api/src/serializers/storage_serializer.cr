class StorageSerializer < BaseSerializer
  def initialize(
    @usage : StorageUsage::UserUsage,
    @projects : Array(StorageUsage::ProjectTotal),
    @server_total : Int64,
    @free_bytes : Int64?,
  )
  end

  def render
    {
      used_bytes:           @usage.total,
      builds_bytes:         @usage.builds,
      sessions_bytes:       @usage.sessions,
      images_bytes:         @usage.images,
      limit_bytes:          AppSettings.account_storage_limit,
      project_limit_bytes:  AppSettings.project_storage_limit,
      server_used_bytes:    @server_total,
      server_limit_bytes:   AppSettings.server_storage_limit,
      server_free_bytes:    @free_bytes,
      server_reserve_bytes: AppSettings.storage_reserve,
      projects:             projects,
    }
  end

  private def projects
    @projects.map do |project|
      {slug: project.slug, title: project.title, used_bytes: project.used_bytes}
    end
  end
end

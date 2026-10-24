class Api::V1::Impersonation::Delete < ApiAction
  include Api::Auth::SkipRequireSession

  # Ending the view is the one write allowed in impersonation. Without the
  # admin cookie the second cookie is inert, so answering 204 is enough.
  def self.allow_impersonation_writes? : Bool
    true
  end

  delete "/api/v1/impersonation" do
    if admin = stop_impersonation
      Log.info { "impersonation.stop admin_id=#{admin.id} ip=#{context.request.remote_ip}" }
      json MeSerializer.new(admin)
    else
      head 204
    end
  end
end

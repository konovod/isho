class Api::V1::SignIns::Delete < ApiAction
  # Signing out is allowed while impersonating: it closes both sessions.
  def self.allow_impersonation_writes? : Bool
    true
  end

  delete "/api/v1/sign_ins" do
    sign_out
    head 204
  end
end

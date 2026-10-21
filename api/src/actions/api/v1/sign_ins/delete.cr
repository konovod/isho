class Api::V1::SignIns::Delete < ApiAction
  delete "/api/v1/sign_ins" do
    sign_out
    head 204
  end
end

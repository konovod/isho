class Api::V1::Admin::Users::Delete < ApiAction
  include Api::Auth::RequireAdmin

  delete "/api/v1/admin/users/:username" do
    user = UserQuery.new.by_username(params.get(:username)).first? ||
           raise Avram::RecordNotFoundError.new(User.table_name, params.get(:username).to_s)

    if user.id == current_user.id
      json ErrorSerializer.new(
        code: "cannot_delete_self",
        message: "Нельзя удалить свой аккаунт",
      ), status: 422
    else
      DeleteUserAccount.run!(user: user)
      head 204
    end
  end
end

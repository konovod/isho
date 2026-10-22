module Api::V1::Projects::RequireOwner
  macro included
    include Api::V1::Projects::ProjectParams

    before require_project_owner

    # Registered after the ownership check: a banned stranger still gets 404
    # for someone else's draft instead of a hint that it exists.
    include Api::Auth::RequireNotBanned
  end

  private def require_project_owner
    unless project.user_id == current_user.id
      # Return 404 instead of 403 so draft existence is not leaked.
      raise Avram::RecordNotFoundError.new(Project.table_name, params.get(:slug).to_s)
    end

    continue
  end
end

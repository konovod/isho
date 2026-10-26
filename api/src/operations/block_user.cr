class BlockUser < UserBlock::SaveOperation
  permit_columns blocked_user_id

  before_save do
    if blocker_id.value == blocked_user_id.value
      blocked_user_id.add_error "must be another account"
    end
  end
end

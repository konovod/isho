# Every ban is a separate row, so moderators keep the history: who banned the
# account, for how long, why, and who lifted it early.
class CreateUserBans::V00000000000018 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(UserBan) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to banned_by : User?, on_delete: :nullify
      add reason : String
      add expires_at : Time
      add lifted_at : Time?
      add_belongs_to lifted_by : User?, on_delete: :nullify
    end
  end

  def rollback
    drop table_for(UserBan)
  end
end

class CreateJams::V00000000000032 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Jam) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to user : User, on_delete: :cascade
      # The forum category is created on publish; a draft has none.
      add_belongs_to forum_section : ForumSection?, on_delete: :nullify, unique: true
      add title : String
      add slug : String, unique: true
      add tagline : String?
      add description : String?
      add rules : String?
      add prizes : String?
      add theme : String?
      add results_note : String?
      add banner : JSON::Any?
      # Drafts may be incomplete; publishing validates that all three dates exist.
      add starts_at : Time?
      add submissions_close_at : Time?
      add voting_closes_at : Time?
      add time_zone : String, default: "Europe/Moscow"
      add status : String, default: "draft"
      add judging_mode : String, default: "community"
      add score_scale : Int32, default: 5
      add published_at : Time?
      add canceled_at : Time?
      add cancel_reason : String?
      add_index :status
      add_index :starts_at
      add_index :submissions_close_at
      add_index :voting_closes_at
    end
  end

  def rollback
    drop table_for(Jam)
  end
end

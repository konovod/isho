class Jam < BaseModel
  include Latch::Avram::Model

  table do
    belongs_to user : User
    belongs_to forum_section : ForumSection?
    column title : String
    column slug : String
    column tagline : String?
    column description : String?
    column rules : String?
    column prizes : String?
    column theme : String?
    column results_note : String?
    attach banner : JamBannerUploader::StoredFile?
    column starts_at : Time?
    column submissions_close_at : Time?
    column voting_closes_at : Time?
    column time_zone : String
    column status : String
    # "community" is the default: every signed-in account can score entries.
    column judging_mode : String
    column score_scale : Int32
    column published_at : Time?
    column canceled_at : Time?
    column cancel_reason : String?
    has_many criteria : JamCriterion
    has_many entries : JamEntry
  end

  def draft? : Bool
    status == "draft"
  end

  def published? : Bool
    status == "published"
  end

  def canceled? : Bool
    status == "canceled"
  end
end

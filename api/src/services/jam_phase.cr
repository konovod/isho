# A jam has no background jobs: its phase follows from the stored dates.
# Draft and canceled are explicit statuses; the rest is derived.
module JamPhase
  enum Phase
    Draft
    Upcoming
    Open
    Judging
    Finished
    Canceled
  end

  def self.for(jam : Jam, now : Time = Time.utc) : Phase
    return Phase::Canceled if jam.canceled?
    return Phase::Draft unless jam.published?

    starts_at = jam.starts_at
    submissions_close_at = jam.submissions_close_at
    voting_closes_at = jam.voting_closes_at

    return Phase::Upcoming unless starts_at && now >= starts_at
    return Phase::Open unless submissions_close_at && now >= submissions_close_at
    return Phase::Judging unless voting_closes_at && now >= voting_closes_at

    Phase::Finished
  end

  def self.key(jam : Jam, now : Time = Time.utc) : String
    self.for(jam, now).to_s.downcase
  end

  def self.accepts_entries?(jam : Jam, now : Time = Time.utc) : Bool
    self.for(jam, now).open?
  end

  def self.accepts_scores?(jam : Jam, now : Time = Time.utc) : Bool
    self.for(jam, now).judging?
  end

  def self.results_visible?(jam : Jam, now : Time = Time.utc) : Bool
    self.for(jam, now).finished?
  end

  def self.theme_visible_to?(jam : Jam, viewer : User?, now : Time = Time.utc) : Bool
    return true if viewer && (viewer.id == jam.user_id || viewer.moderator?)
    return false unless jam.published?

    starts_at = jam.starts_at
    !!starts_at && now >= starts_at
  end

  # The phase the countdown points at. nil after the jam is over.
  def self.next_at(jam : Jam, now : Time = Time.utc) : Time?
    case self.for(jam, now)
    when Phase::Upcoming
      jam.starts_at
    when Phase::Open
      jam.submissions_close_at
    when Phase::Judging
      jam.voting_closes_at
    end
  end
end

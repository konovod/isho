# Scoring rules shared by the scoring page, results and feedback.
#
# Everybody may vote. `judging_mode` only decides whose scorecards count in
# the totals:
#   community    - every account's scores count;
#   participants - only accounts with a submitted entry can affect the result.
# Feedback from the remaining votes is still delivered to the entry author.
module JamScoring
  def self.started?(jam : Jam) : Bool
    entry_ids = JamEntryQuery.new.for_jam(jam.id).results.map(&.id)
    return false if entry_ids.empty?

    !JamScoreQuery.new.for_entries(entry_ids).select_count.zero?
  end

  def self.locked?(jam : Jam) : Bool
    started?(jam)
  end

  def self.participant_ids(jam : Jam) : Array(Int64)
    JamEntryQuery.new.for_jam(jam.id).submitted.results.map(&.user_id).uniq
  end

  def self.counted?(jam : Jam, voter_id : Int64, participant_ids : Array(Int64)) : Bool
    if jam.judging_mode == "participants"
      participant_ids.includes?(voter_id)
    else
      true
    end
  end
end

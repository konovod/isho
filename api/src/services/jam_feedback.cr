# Text feedback is the main thing authors get out of a jam. Voters stay
# anonymous to the author; organizers see the voter for moderation.
module JamFeedback
  record Item, score : JamScore, counted : Bool

  record CriterionFeedback,
    criterion : JamCriterion,
    average : Float64,
    items : Array(Item)

  record Result,
    entry : JamEntry,
    criteria : Array(CriterionFeedback),
    counted_votes : Int32,
    total_votes : Int32,
    mode : String

  def self.for(jam : Jam, entry : JamEntry) : Result
    criteria = JamCriterionQuery.new.for_jam(jam.id).ordered.results
    scores = JamScoreQuery.new.for_entry(entry.id).preload_user.newest.results
    participant_ids = JamScoring.participant_ids(jam)
    grouped = scores.group_by(&.user_id)

    counted_user_ids = grouped.keys.select do |user_id|
      user_id != entry.user_id && JamScoring.counted?(jam, user_id, participant_ids)
    end

    feedback = criteria.map do |criterion|
      items = grouped.flat_map do |user_id, rows|
        row = rows.find { |item| item.criterion_id == criterion.id }
        next [] of Item unless row

        [Item.new(row, counted_user_ids.includes?(user_id))]
      end

      values = items.select(&.counted).map(&.score.score)
      average = values.empty? ? 0.0 : values.sum.to_f / values.size
      CriterionFeedback.new(criterion, average, items)
    end

    Result.new(
      entry,
      feedback,
      counted_user_ids.size,
      grouped.size,
      jam.judging_mode,
    )
  end
end

module JamResults
  record CriterionAverage, criterion : JamCriterion, average : Float64

  record EntryResult,
    entry : JamEntry,
    total : Float64,
    max_total : Int32,
    votes_count : Int32,
    place : Int32?,
    criteria : Array(CriterionAverage)

  # One voter's complete scorecard: a row per criterion.
  record Scorecard, user_id : Int64, scores : Hash(Int64, JamScore)

  def self.for(jam : Jam, viewer : User?, preview : Bool = false) : Array(EntryResult)
    criteria = JamCriterionQuery.new.for_jam(jam.id).ordered.results
    return [] of EntryResult if criteria.empty?

    entries = JamEntryQuery.new.for_jam(jam.id).submitted.preload_card.results
    entries = JamEntryVisibility.visible(entries, viewer) unless preview
    return [] of EntryResult if entries.empty?

    scores = JamScoreQuery.new.for_entries(entries.map(&.id)).results
    scores_by_entry = scores.group_by(&.entry_id)
    participant_ids = JamScoring.participant_ids(jam)
    criterion_ids = criteria.map(&.id)
    total_weight = criteria.sum(&.weight)
    max_total = jam.score_scale * total_weight

    results = entries.map do |entry|
      scorecards = build_scorecards(scores_by_entry[entry.id]? || [] of JamScore, criterion_ids)
      counted = scorecards.select do |card|
        card.user_id != entry.user_id && JamScoring.counted?(jam, card.user_id, participant_ids)
      end

      totals = counted.map { |card| weighted_sum(card, criteria) }
      total = totals.empty? ? 0.0 : (totals.sum / totals.size).round(2)

      averages = criteria.map do |criterion|
        values = counted.compact_map { |card| card.scores[criterion.id]?.try(&.score) }
        average = values.empty? ? 0.0 : values.sum.to_f / values.size
        CriterionAverage.new(criterion, average)
      end

      EntryResult.new(entry, total, max_total, counted.size, nil, averages)
    end

    rank(results)
  end

  private def self.build_scorecards(scores : Array(JamScore), criterion_ids : Array(Int64)) : Array(Scorecard)
    scores
      .group_by(&.user_id)
      .compact_map do |user_id, rows|
        by_criterion = rows.to_h { |row| {row.criterion_id, row} }
        next unless criterion_ids.all? { |id| by_criterion.has_key?(id) }

        Scorecard.new(user_id, by_criterion)
      end
  end

  private def self.weighted_sum(card : Scorecard, criteria : Array(JamCriterion)) : Float64
    criteria.sum do |criterion|
      (card.scores[criterion.id].score * criterion.weight).to_f
    end
  end

  # Standard competition ranking: equal totals share a place, the next place
  # skips the tied positions. Entries without counted votes go to the end.
  private def self.rank(results : Array(EntryResult)) : Array(EntryResult)
    with_scores = results.select { |result| result.votes_count > 0 }
      .sort do |left, right|
        comparison = (right.total <=> left.total) || 0
        comparison = right.votes_count <=> left.votes_count if comparison.zero?
        comparison = left.entry.created_at <=> right.entry.created_at if comparison.zero?
        comparison = left.entry.id <=> right.entry.id if comparison.zero?
        comparison
      end

    without_scores = results
      .select { |result| result.votes_count.zero? }
      .sort_by { |result| {result.entry.created_at, result.entry.id} }

    ranked = [] of EntryResult

    with_scores.each_with_index do |result, index|
      previous = ranked.last?
      place = previous && previous.total == result.total ? previous.place : index + 1
      ranked << EntryResult.new(
        result.entry,
        result.total,
        result.max_total,
        result.votes_count,
        place,
        result.criteria,
      )
    end

    without_scores.each do |result|
      ranked << EntryResult.new(
        result.entry,
        result.total,
        result.max_total,
        result.votes_count,
        nil,
        result.criteria,
      )
    end

    ranked
  end
end

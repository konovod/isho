class Api::V1::Jams::Entries::Scores::Update < ApiAction
  include Api::V1::Jams::JamParams
  include Api::V1::Jams::EntryParams
  include Api::Auth::RequireConfirmedEmail
  include Api::Auth::RequireNotBanned

  put "/api/v1/jams/:slug/entries/:id/scores" do
    unless JamPhase.accepts_scores?(jam)
      return json ErrorSerializer.new(
        code: "judging_closed",
        message: "Судейство ещё не началось или уже закончилось",
      ), status: 422
    end

    unless entry.submitted?
      return json ErrorSerializer.new(
        code: "entry_disqualified",
        message: "Снятую заявку оценивать нельзя",
      ), status: 422
    end

    if entry.user_id == current_user.id
      return json ErrorSerializer.new(
        code: "own_entry",
        message: "Свою заявку оценивать нельзя",
      ), status: 422
    end

    unless current_user.id == jam.user_id || current_user.moderator?
      unless JamEntryVisibility.visible?(entry, current_user)
        raise Avram::RecordNotFoundError.new(JamEntry.table_name, params.get(:id).to_s)
      end
    end

    criteria = jam.criteria.sort_by(&.position)
    if criteria.empty?
      return json ErrorSerializer.new(
        code: "criteria_missing",
        message: "У джема нет критериев для оценки",
      ), status: 422
    end

    rows = params.many_nested?("jam_scores")

    values, error = parse_scores(rows, criteria, jam.score_scale)
    if error
      return json error.not_nil!, status: 422
    end

    SaveJamScorecard.run!(
      entry: entry,
      user: current_user,
      values: values.not_nil!,
    )

    scores = JamScoreQuery.new
      .for_entry(entry.id)
      .for_user(current_user.id)
      .results

    json JamScoringEntrySerializer.new(reload_entry(entry), scores, true)
  end

  private def parse_scores(
    rows : Array(Hash(String, String)),
    criteria : Array(JamCriterion),
    scale : Int32,
  ) : Tuple(Array(JamScoreInput)?, ErrorSerializer?)
    details = {} of String => Array(String)
    by_criterion = {} of Int64 => JamScoreInput

    rows.each do |row|
      criterion_id = row["criterion_id"]?.try(&.to_i64?)
      score = row["score"]?.try(&.to_i?)
      comment = row["comment"]?.to_s.strip
      comment = nil if comment.empty?

      unless criterion_id
        details["criterion_id"] = ["is invalid"]
        next
      end

      unless criteria.any? { |criterion| criterion.id == criterion_id }
        details["criterion_id"] = ["does not belong to this jam"]
        next
      end

      if by_criterion.has_key?(criterion_id)
        details["criterion_id"] = ["is duplicated"]
        next
      end

      unless score && (1..scale).includes?(score)
        details["score"] = ["is out of range"]
        next
      end

      if comment && comment.size > AppSettings::JAM_FEEDBACK_MAX_CHARS
        details["comment"] = ["is too long"]
        next
      end

      by_criterion[criterion_id] = JamScoreInput.new(criterion_id, score, comment)
    end

    unless criteria.all? { |criterion| by_criterion.has_key?(criterion.id) }
      details["jam_scores"] = ["must include every criterion"]
    end

    if details.empty?
      values = criteria.map { |criterion| by_criterion[criterion.id] }
      {values, nil}
    else
      {nil, ErrorSerializer.new(
        code: "validation_failed",
        message: "Проверьте оценки и отзывы",
        details: details,
      )}
    end
  end
end

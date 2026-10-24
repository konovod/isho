class Api::V1::Jams::Index < ApiAction
  include Api::Auth::SkipRequireSession

  get "/api/v1/jams" do
    page = (params.get?(:page).try(&.to_i?) || 1).clamp(1, 10_000)
    per_page = (params.get?(:per_page).try(&.to_i?) || AppSettings::JAMS_PER_PAGE).clamp(1, 48)
    now = Time.utc

    query = JamQuery.new.published.preload_card

    if term = params.get?(:q).try(&.strip)
      query = query.search(term) unless term.empty?
    end

    jams = query.results

    if phase = params.get?(:phase).try(&.strip.downcase)
      unless phase.empty? || phase == "all"
        jams = jams.select { |jam| JamPhase.key(jam, now) == phase }
      end
    end

    jams = sort_jams(jams, now)
    total = jams.size.to_i64
    items = jams[(page - 1) * per_page, per_page]? || [] of Jam

    json({
      items: items.map { |jam| JamSerializer.new(jam, current_user?) },
      meta:  {
        page:     page,
        per_page: per_page,
        total:    total,
        pages:    (total + per_page - 1) // per_page,
      },
    })
  end

  # Open and judging jams come first; finished ones are newest first.
  private def sort_jams(jams : Array(Jam), now : Time) : Array(Jam)
    jams.sort do |left, right|
      sort_key(left, now) <=> sort_key(right, now)
    end
  end

  private def sort_key(jam : Jam, now : Time) : Tuple(Int32, Int64, Int64)
    phase = JamPhase.for(jam, now)

    rank = case phase
           when JamPhase::Phase::Upcoming then 0
           when JamPhase::Phase::Open     then 1
           when JamPhase::Phase::Judging  then 2
           when JamPhase::Phase::Finished then 3
           else                                4
           end

    at = case phase
         when JamPhase::Phase::Upcoming then jam.starts_at
         when JamPhase::Phase::Open     then jam.submissions_close_at
         when JamPhase::Phase::Judging  then jam.voting_closes_at
         when JamPhase::Phase::Finished then jam.voting_closes_at
         end

    seconds = at.try(&.to_unix) || 0_i64
    seconds = -seconds if phase.finished?

    {rank, seconds, jam.id}
  end
end

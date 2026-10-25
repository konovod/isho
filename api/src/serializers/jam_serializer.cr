class JamSerializer < BaseSerializer
  def initialize(@jam : Jam, @viewer : User? = nil, @detailed : Bool = false)
  end

  def render
    now = Time.utc
    phase = JamPhase.for(@jam, now)
    theme_visible = JamPhase.theme_visible_to?(@jam, @viewer, now)

    base = {
      id:                   @jam.id,
      slug:                 @jam.slug,
      title:                @jam.title,
      tagline:              @jam.tagline,
      theme:                theme_visible ? @jam.theme : nil,
      theme_visible:        theme_visible,
      banner_url:           public_url(@jam.banner.try(&.url)),
      banner_card_url:      public_url(@jam.banner.try { |file| file.versions_card?.try(&.url) }),
      starts_at:            @jam.starts_at,
      submissions_close_at: @jam.submissions_close_at,
      voting_closes_at:     @jam.voting_closes_at,
      time_zone:            @jam.time_zone,
      status:               @jam.status,
      phase:                phase.to_s.downcase,
      next_phase_at:        JamPhase.next_at(@jam, now),
      judging_mode:         @jam.judging_mode,
      score_scale:          @jam.score_scale,
      published_at:         @jam.published_at,
      canceled_at:          @jam.canceled_at,
      cancel_reason:        @jam.cancel_reason,
      entries_count:        entries_count,
      organizer:            UserSerializer.new(@jam.user),
    }

    return base unless @detailed

    base.merge({
      description:   @jam.description,
      rules:         @jam.rules,
      prizes:        @jam.prizes,
      results_note:  @jam.results_note,
      forum_section: forum_section,
      criteria:      criteria,
      viewer:        viewer(phase),
    })
  end

  private def public_url(url : String?) : String?
    url.try(&.gsub('\\', '/'))
  end

  private def forum_section
    return nil unless @jam.forum_section_id
    return nil unless @jam.forum_section_preloaded?

    section = @jam.forum_section
    return nil unless section

    {id: section.id, slug: section.slug, title: section.title}
  end

  private def criteria
    return [] of JamCriterionSerializer unless @jam.criteria_preloaded?

    @jam.criteria
      .sort_by(&.position)
      .map { |criterion| JamCriterionSerializer.new(criterion) }
  end

  # Cards show how many entries the viewer can actually discover. Organizers
  # and moderators see every submitted entry, including unpublished projects.
  private def entries_count : Int64
    entries = JamEntryQuery.new
      .for_jam(@jam.id)
      .submitted
      .preload_project
      .results

    JamEntryVisibility.count(entries, @viewer)
  end

  private def my_entries : Array(JamEntrySerializer)
    user = @viewer
    return [] of JamEntrySerializer unless user

    JamEntryQuery.new
      .for_jam(@jam.id)
      .user_id(user.id)
      .preload_card
      .newest
      .results
      .map { |entry| JamEntrySerializer.new(entry) }
  end

  private def viewer(phase : JamPhase::Phase)
    user = @viewer
    return nil unless user

    organizer = user.id == @jam.user_id

    {
      is_organizer:    organizer,
      is_admin:        user.moderator?,
      can_edit:        organizer || user.moderator?,
      can_submit:      phase.open? && user.email_confirmed? && !user.banned?,
      can_score:       phase.judging? && user.email_confirmed? && !user.banned?,
      results_visible: phase.finished?,
      my_entries:      my_entries,
    }
  end
end

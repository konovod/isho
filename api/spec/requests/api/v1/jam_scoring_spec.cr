require "../../../spec_helper"

private def judging_jam(owner : User? = nil, mode : String = "community") : Jam
  now = Time.utc
  jam = JamFactory.create &.status("published").published_at(now)
    .starts_at(now - 3.days)
    .submissions_close_at(now - 1.day)
    .voting_closes_at(now + 1.day)
    .judging_mode(mode)

  Jam::SaveOperation.update!(jam, user_id: owner.id) if owner
  JamQuery.new.id(jam.id).first?.not_nil!
end

private def finished_jam(mode : String = "community") : Jam
  now = Time.utc
  JamFactory.create &.status("published").published_at(now)
    .starts_at(now - 5.days)
    .submissions_close_at(now - 3.days)
    .voting_closes_at(now - 1.day)
    .judging_mode(mode)
end

private def open_jam : Jam
  now = Time.utc
  JamFactory.create &.status("published").published_at(now)
    .starts_at(now - 1.day)
    .submissions_close_at(now + 1.day)
    .voting_closes_at(now + 2.days)
end

private def criterion_for(jam : Jam, title : String = "Геймплей", weight : Int32 = 1) : JamCriterion
  JamCriterionFactory.create &.jam_id(jam.id).title(title).weight(weight)
end

private def entry_for(jam : Jam, user : User? = nil, project : Project? = nil) : JamEntry
  user ||= UserFactory.create
  project ||= ProjectFactory.create &.user_id(user.id).status("published").published_at(Time.utc)
  JamEntryFactory.create &.jam_id(jam.id).project_id(project.id).user_id(user.id)
end

private def add_score(entry : JamEntry, user : User, criterion : JamCriterion, score : Int32, comment : String? = nil) : JamScore
  JamScore::SaveOperation.create!(
    entry_id: entry.id,
    user_id: user.id,
    criterion_id: criterion.id,
    score: score,
    comment: comment,
  )
end

describe Api::V1::Jams::Scoring do
  describe "PUT /api/v1/jams/:slug/entries/:id/scores" do
    it "saves scores and per-criterion feedback from any user" do
      jam = judging_jam
      criterion = criterion_for(jam)
      entry = entry_for(jam)
      voter = UserFactory.create

      response = AuthHelper.client_for(voter).put(
        "/api/v1/jams/#{jam.slug}/entries/#{entry.id}/scores",
        jam_scores: [
          {criterion_id: criterion.id, score: 4, comment: "Хорошая петля"},
        ],
      )

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["complete"].as_bool.should be_true
      body["my_scores"].as_a.first["score"].as_i.should eq 4
      body["my_scores"].as_a.first["comment"].as_s.should eq "Хорошая петля"

      stored = JamScoreQuery.new.for_entry(entry.id).for_user(voter.id).first?.not_nil!
      stored.score.should eq 4
      stored.comment.should eq "Хорошая петля"
    end

    it "rejects a score for the voter's own entry" do
      jam = judging_jam
      criterion = criterion_for(jam)
      author = UserFactory.create
      entry = entry_for(jam, author)

      response = AuthHelper.client_for(author).put(
        "/api/v1/jams/#{jam.slug}/entries/#{entry.id}/scores",
        jam_scores: [{criterion_id: criterion.id, score: 5}],
      )

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "own_entry"
    end

    it "rejects scoring outside the judging window" do
      jam = open_jam
      criterion = criterion_for(jam)
      entry = entry_for(jam)
      voter = UserFactory.create

      response = AuthHelper.client_for(voter).put(
        "/api/v1/jams/#{jam.slug}/entries/#{entry.id}/scores",
        jam_scores: [{criterion_id: criterion.id, score: 4}],
      )

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "judging_closed"
    end

    it "requires every criterion and a score in range" do
      jam = judging_jam
      first = criterion_for(jam, "Геймплей")
      second = criterion_for(jam, "Визуал")
      entry = entry_for(jam)
      voter = UserFactory.create
      client = AuthHelper.client_for(voter)

      missing = client.put(
        "/api/v1/jams/#{jam.slug}/entries/#{entry.id}/scores",
        jam_scores: [{criterion_id: first.id, score: 4}],
      )
      missing.status_code.should eq 422
      JSON.parse(missing.body)["error"]["details"]["jam_scores"].as_a.should_not be_empty

      out_of_range = client.put(
        "/api/v1/jams/#{jam.slug}/entries/#{entry.id}/scores",
        jam_scores: [
          {criterion_id: first.id, score: 6},
          {criterion_id: second.id, score: 4},
        ],
      )
      out_of_range.status_code.should eq 422
      JSON.parse(out_of_range.body)["error"]["details"]["score"].as_a.should_not be_empty
    end

    it "replaces the previous scorecard" do
      jam = judging_jam
      criterion = criterion_for(jam)
      entry = entry_for(jam)
      voter = UserFactory.create
      client = AuthHelper.client_for(voter)

      client.put(
        "/api/v1/jams/#{jam.slug}/entries/#{entry.id}/scores",
        jam_scores: [{criterion_id: criterion.id, score: 2, comment: "Слабо"}],
      ).status_code.should eq 200

      client.put(
        "/api/v1/jams/#{jam.slug}/entries/#{entry.id}/scores",
        jam_scores: [{criterion_id: criterion.id, score: 5, comment: "Сильно"}],
      ).status_code.should eq 200

      scores = JamScoreQuery.new.for_entry(entry.id).for_user(voter.id).results
      scores.size.should eq 1
      scores.first.score.should eq 5
      scores.first.comment.should eq "Сильно"
    end
  end

  describe "GET /api/v1/jams/:slug/scoring" do
    it "lists entries except the viewer's own and the entered scorecards" do
      jam = judging_jam
      criterion = criterion_for(jam)
      voter = UserFactory.create
      entry_for(jam, voter)
      other = entry_for(jam)
      client = AuthHelper.client_for(voter)

      client.put(
        "/api/v1/jams/#{jam.slug}/entries/#{other.id}/scores",
        jam_scores: [{criterion_id: criterion.id, score: 4}],
      ).status_code.should eq 200

      response = client.get("/api/v1/jams/#{jam.slug}/scoring")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["items"].as_a.size.should eq 1
      body["items"].as_a.first["entry"]["id"].as_i64.should eq other.id
      body["items"].as_a.first["complete"].as_bool.should be_true
      body["progress"]["scored"].as_i.should eq 1
      body["progress"]["total"].as_i.should eq 1
    end
  end

  describe "GET /api/v1/jams/:slug/results" do
    it "is unavailable before the judging window closes" do
      jam = judging_jam
      entry_for(jam)

      response = ApiClient.new.get("/api/v1/jams/#{jam.slug}/results")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["available"].as_bool.should be_false
      body["items"].as_a.should be_empty
    end

    it "ranks entries by counted totals and exposes per-criterion averages" do
      jam = finished_jam
      criterion = criterion_for(jam)
      first = entry_for(jam)
      second = entry_for(jam)
      third = entry_for(jam)
      voter_a = UserFactory.create
      voter_b = UserFactory.create

      add_score(first, voter_a, criterion, 5)
      add_score(first, voter_b, criterion, 1)
      add_score(second, voter_a, criterion, 3)
      add_score(second, voter_b, criterion, 5)

      response = ApiClient.new.get("/api/v1/jams/#{jam.slug}/results")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["available"].as_bool.should be_true
      items = body["items"].as_a
      items.map(&.["entry_id"].as_i64).should eq [second.id, first.id, third.id]
      items[0]["place"].as_i.should eq 1
      items[0]["total"].as_f.should eq 4.0
      items[0]["votes_count"].as_i.should eq 2
      items[0]["criteria"].as_a.first["average"].as_f.should eq 4.0
      items[1]["place"].as_i.should eq 2
      items[1]["total"].as_f.should eq 3.0
      items[2]["place"].as_nil.should be_nil
    end

    it "counts only participants in participants mode" do
      jam = finished_jam(mode: "participants")
      criterion = criterion_for(jam)
      target = entry_for(jam)
      participant = UserFactory.create
      entry_for(jam, participant)
      outsider = UserFactory.create

      add_score(target, participant, criterion, 5)
      add_score(target, outsider, criterion, 1)

      response = ApiClient.new.get("/api/v1/jams/#{jam.slug}/results")

      response.status_code.should eq 200
      item = JSON.parse(response.body)["items"].as_a.first
      item["total"].as_f.should eq 5.0
      item["votes_count"].as_i.should eq 1
    end

    it "lets the organizer preview results before the end" do
      organizer = UserFactory.create
      jam = judging_jam(owner: organizer)
      criterion = criterion_for(jam)
      entry = entry_for(jam)
      add_score(entry, UserFactory.create, criterion, 4)

      response = AuthHelper.client_for(organizer).get("/api/v1/jams/#{jam.slug}/results?preview=true")

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["available"].as_bool.should be_true
      body["items"].as_a.size.should eq 1
    end
  end

  describe "GET /api/v1/jams/:slug/entries/:id/feedback" do
    it "shows anonymous feedback to the entry author after judging" do
      jam = finished_jam
      criterion = criterion_for(jam)
      author = UserFactory.create
      entry = entry_for(jam, author)
      voter = UserFactory.create
      add_score(entry, voter, criterion, 4, "Хороший уровень")

      response = AuthHelper.client_for(author).get(
        "/api/v1/jams/#{jam.slug}/entries/#{entry.id}/feedback",
      )

      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body["counted_votes"].as_i.should eq 1
      item = body["criteria"].as_a.first["items"].as_a.first
      item["comment"].as_s.should eq "Хороший уровень"
      item["voter"].as_nil.should be_nil
    end

    it "shows the voter to the organizer" do
      organizer = UserFactory.create
      jam = finished_jam
      Jam::SaveOperation.update!(jam, user_id: organizer.id)
      criterion = criterion_for(jam)
      entry = entry_for(jam)
      voter = UserFactory.create
      add_score(entry, voter, criterion, 4, "Комментарий")

      response = AuthHelper.client_for(organizer).get(
        "/api/v1/jams/#{jam.slug}/entries/#{entry.id}/feedback",
      )

      response.status_code.should eq 200
      JSON.parse(response.body)["criteria"].as_a.first["items"].as_a.first["voter"]["username"]
        .as_s.should eq voter.username
    end

    it "keeps feedback hidden from the author until judging ends" do
      jam = judging_jam
      criterion = criterion_for(jam)
      author = UserFactory.create
      entry = entry_for(jam, author)
      add_score(entry, UserFactory.create, criterion, 4, "Рано")

      response = AuthHelper.client_for(author).get(
        "/api/v1/jams/#{jam.slug}/entries/#{entry.id}/feedback",
      )

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["code"].as_s.should eq "feedback_not_ready"
    end
  end

  describe "scoring locks" do
    it "does not allow criteria or mode changes after the first score" do
      organizer = UserFactory.create
      jam = judging_jam(owner: organizer)
      criterion = criterion_for(jam)
      entry = entry_for(jam)
      client = AuthHelper.client_for(organizer)

      client.put(
        "/api/v1/jams/#{jam.slug}/entries/#{entry.id}/scores",
        jam_scores: [{criterion_id: criterion.id, score: 4}],
      ).status_code.should eq 200

      criteria_response = client.patch(
        "/api/v1/jams/#{jam.slug}/criteria/#{criterion.id}",
        jam_criterion: {title: "Новое имя"},
      )
      criteria_response.status_code.should eq 422
      JSON.parse(criteria_response.body)["error"]["code"].as_s.should eq "criteria_locked"

      mode_response = client.patch(
        "/api/v1/jams/#{jam.slug}",
        jam: {judging_mode: "participants"},
      )
      mode_response.status_code.should eq 422
      JSON.parse(mode_response.body)["error"]["details"]["judging_mode"].as_a.should_not be_empty
    end

    it "rejects the removed jury mode" do
      user = UserFactory.create

      response = AuthHelper.client_for(user).post("/api/v1/jams", jam: {
        title:        "Джем",
        judging_mode: "jury",
      })

      response.status_code.should eq 422
      JSON.parse(response.body)["error"]["details"]["judging_mode"].as_a.should_not be_empty
    end
  end
end

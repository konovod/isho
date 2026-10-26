require "json"

# The whole import, step by step. One page read, one model call, one draft.
#
# The project row appears only after the page was understood: a failed fetch
# leaves no empty draft behind, and the author always gets a normal project they
# can edit, publish or delete with the usual screens.
module Import::Runner
  # Title, description, candidates and the lists of tags and genres take their
  # share of the prompt; the rest is page text.
  TEXT_BUDGET   = AppSettings::IMPORT_MAX_INPUT_CHARS - 2_500
  PROMPT_IMAGES = 30
  PROMPT_LINKS  = 15
  RETRY_DELAY   = 2.minutes

  def self.perform(job : ImportJob) : Nil
    page = read_page(job)

    if page.thin?
      Import::Jobs.skip!(job, "на странице нет текста")
      return
    end

    tags = TagQuery.new.results
    completion = ask(job, page, tags)
    usage = completion.usage

    plan = Import::Plan.from(Ai::Json.object(completion.text), page, tags)
    unless plan
      Import::Jobs.skip!(job, "не удалось разобрать страницу", usage.prompt_tokens, usage.completion_tokens)
      return
    end

    if cancelled?(job)
      return
    end

    project = create_draft(job, plan, page)
    Import::Jobs.step!(job, "screenshots")
    Import::Images.attach(project, job.user_id, plan.image_urls)

    Import::Jobs.complete!(
      job,
      project.id,
      usage.prompt_tokens,
      usage.completion_tokens,
      summary(plan),
    )
  rescue error : Import::Unavailable | Ai::Unavailable
    Import::Jobs.retry_later!(job, error.message.to_s, RETRY_DELAY)
  rescue error : Import::Failed | Ai::Rejected
    Import::Jobs.fail!(job, error.message.to_s)
  end

  private def self.read_page(job : ImportJob) : Import::Page
    Import::Jobs.step!(job, "fetch")
    fetched = Import::Fetcher.page(job.source_url)

    Import::Jobs.step!(job, "extract")
    Import::Extractor.extract(fetched.url, fetched.text)
  end

  private def self.ask(job : ImportJob, page : Import::Page, tags : Array(Tag)) : Ai::Completion
    Import::Jobs.step!(job, "ai")

    # Only the head of the list is shown: a gallery of forty pictures would cost
    # more than the answer is worth.
    images = page.images.first(PROMPT_IMAGES)
    links = candidates(page.links)

    Ai.complete(
      [
        Ai::Message.new("system", Ai::Prompts::IMPORT_SYSTEM),
        Ai::Message.new("user", Ai::Prompts.import_page(page, tags, images, links, TEXT_BUDGET)),
      ],
      max_tokens: AppSettings::IMPORT_MAX_TOKENS,
      temperature: 0.3,
      json_response: true,
      timeout: AppSettings.ai_answer_timeout,
    )
  end

  # Links worth showing the model: obvious build files and links that promise a
  # download. The plan still only accepts a URL the page really linked to.
  private def self.candidates(links : Array({String, String})) : Array({String, String})
    interesting = links.select do |(url, label)|
      path = url.split('?').first.downcase
      build = AppSettings::IMPORT_FILE_EXTENSIONS.any? { |extension| path.ends_with?(extension) }
      build || label.matches?(/скачат|download|build|сборк|билд|release/i)
    end

    (interesting.empty? ? links.first(PROMPT_LINKS) : interesting.first(PROMPT_LINKS))
  end

  private def self.create_draft(job : ImportJob, plan : Import::Plan::Draft, page : Import::Page) : Project
    project = nil

    AppDatabase.transaction do
      project = SaveProject.create!(
        title: plan.title,
        tagline: plan.tagline,
        description: plan.description,
        kind: plan.kind,
        dev_status: plan.dev_status,
        genre: plan.genre,
        nsfw: plan.nsfw,
        source_url: page.source_url,
        user_id: job.user_id,
      )

      SetProjectTags.new(project: project, tag_names: plan.tags).run

      if url = plan.download_url
        CreateDownload.create!(
          project_id: project.id,
          url: url,
          label: plan.download_label || "Скачать",
          platform: plan.download_platform,
        )
      end
    end

    project.not_nil!
  end

  private def self.cancelled?(job : ImportJob) : Bool
    fresh = ImportJobQuery.new.id(job.id).first?
    fresh.nil? || fresh.status == "cancelled"
  end

  private def self.summary(plan : Import::Plan::Draft) : String
    {
      title:        plan.title,
      kind:         plan.kind,
      dev_status:   plan.dev_status,
      genre:        plan.genre,
      tags:         plan.tags,
      screenshots:  plan.image_urls.size,
      download_url: plan.download_url,
    }.to_json
  end
end

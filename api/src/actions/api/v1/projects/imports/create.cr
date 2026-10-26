require "uri"

# Queues an import: the page is read and the draft is built in the background,
# because a slow site must not hold a request open.
class Api::V1::Projects::Imports::Create < ApiAction
  include Api::Auth::RequireConfirmedEmail
  include Api::Auth::RequireNotBanned

  post "/api/v1/projects/imports" do
    unless AppSettings.import_enabled?
      return json ErrorSerializer.new(
        code: "import_disabled",
        message: "Импорт по ссылке сейчас недоступен",
      ), status: 503
    end

    raw = params.nested?("import")["source_url"]?.to_s.strip

    if raw.empty?
      return json ErrorSerializer.new(
        code: "validation_failed",
        message: "Нужна ссылка на страницу игры",
        details: {"source_url" => ["is required"]},
      ), status: 422
    end

    url = begin
      Import::UrlGuard.check(raw)
    rescue error : Import::UrlGuard::Blocked
      return json ErrorSerializer.new(
        code: "invalid_url",
        message: error.message || "Ссылка не подходит",
        details: {"source_url" => ["is not allowed"]},
      ), status: 422
    end

    job = nil
    failure = nil

    AppDatabase.transaction do
      # Serialises starts per account so a double click cannot queue two jobs.
      AppDatabase.run do |db|
        db.exec("SELECT id FROM users WHERE id = $1 FOR UPDATE", current_user.id)
      end

      if ImportJobQuery.new.for_user(current_user.id).active.first?
        failure = {"import_in_progress", "Импорт уже идёт. Дождитесь его окончания.", 422}
      elsif !Ai::Quota.consume(current_user, "project_import", AppSettings.import_jobs_per_day)
        failure = {"import_limit_reached", "На сегодня импорты закончились. Попробуйте завтра.", 422}
      else
        job = Import::Jobs.enqueue(current_user, url.to_s)
      end
    end

    if failure
      code, message, status = failure
      return json ErrorSerializer.new(code: code, message: message), status: status
    end

    json({import: ImportJobSerializer.new(job.not_nil!)}, status: 202)
  end
end

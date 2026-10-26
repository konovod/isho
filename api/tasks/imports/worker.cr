class Import::WorkerTask < LuckyTask::Task
  name "imports.worker"
  summary "Process queued project imports (page, model call, screenshots)"

  switch once, "Process at most one job and exit"
  switch verbose, "Log every step"

  def call
    Import::Worker.start(once: once?, verbose: verbose?)
  end
end

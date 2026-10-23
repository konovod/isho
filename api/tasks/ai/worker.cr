class Ai::WorkerTask < LuckyTask::Task
  name "ai.worker"
  summary "Process queued AI jobs (forum answers and user flair)"

  switch once, "Process at most one job and exit"
  switch verbose, "Log every step"

  def call
    Ai::Worker.start(once: once?, verbose: verbose?)
  end
end

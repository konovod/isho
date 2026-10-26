# Imports have their own switch and their own fake network, so no example can
# reach a real site.
Spec.before_each do
  ENV.delete("IMPORT_ENABLED")
  ENV.delete("IMPORT_JOBS_PER_DAY")
  Import::Transport.backend = ImportFakeBackend.new
  stub_dns
end

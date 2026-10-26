# Import jobs are written only through operations, so status and timestamps
# stay consistent. `Import::Jobs` is the only caller.
class SaveImportJob < ImportJob::SaveOperation
end

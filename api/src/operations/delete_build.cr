# Deletes a build and the files behind it. Web builds live in their own
# directory; downloadable builds are Latch attachments.
class DeleteBuild < Avram::Operation
  needs build : Build

  def run
    BuildStorage.delete_files(build)
    Build::DeleteOperation.delete!(build)
  end
end

# LEGACY: pre-rename projects API, identical to the old public surface.
# Kept so front ends deployed before the projects -> challenges rename
# keep working. Delete once the front end has been deployed.
class Internal::Projects::ExerciseSubmissionsController < Internal::Challenges::ExerciseSubmissionsController
  private
  # The parent's before_action / rescue_from hooks call these, so overriding
  # them swaps in the legacy :project_slug param and legacy error keys.
  def use_challenge! = use_project!
  def render_challenge_locked_error(_exception) = render_403(:project_locked)
end

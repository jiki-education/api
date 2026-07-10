# LEGACY: pre-rename projects API. The output is identical to
# SerializeAdminChallenges. Delete once the legacy projects endpoints are removed.
class SerializeAdminProjects
  include Mandate

  initialize_with :challenges

  def call = SerializeAdminChallenges.(challenges)
end

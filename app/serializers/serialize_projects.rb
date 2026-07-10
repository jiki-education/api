# LEGACY: pre-rename projects API. The output is identical to
# SerializeChallenges. Delete once the legacy projects endpoints are removed.
class SerializeProjects
  include Mandate

  initialize_with :challenges, for_user: nil

  def call = SerializeChallenges.(challenges, for_user:)
end

# LEGACY: pre-rename projects API. The output is identical to
# SerializeChallenge. Delete once the legacy projects endpoints are removed.
class SerializeProject
  include Mandate

  initialize_with :challenge

  def call = SerializeChallenge.(challenge)
end

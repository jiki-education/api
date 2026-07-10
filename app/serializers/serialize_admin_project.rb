# LEGACY: pre-rename projects API. The output is identical to
# SerializeAdminChallenge. Delete once the legacy projects endpoints are removed.
class SerializeAdminProject
  include Mandate

  initialize_with :challenge

  def call = SerializeAdminChallenge.(challenge)
end

# LEGACY: pre-rename projects API. Identical to SerializeUserChallenge
# except the slug key keeps its old project_slug name. Delete once the
# legacy projects endpoints are removed.
class SerializeUserProject
  include Mandate

  initialize_with :user_challenge

  def call
    data = SerializeUserChallenge.(user_challenge)
    data[:project_slug] = data.delete(:challenge_slug)
    data
  end
end

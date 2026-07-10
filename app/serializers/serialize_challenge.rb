class SerializeChallenge
  include Mandate

  initialize_with :challenge

  def call
    {
      slug: challenge.slug,
      title: challenge.title,
      description: challenge.description
    }
  end
end

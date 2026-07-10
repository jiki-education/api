class Challenge::Update
  include Mandate

  initialize_with :challenge, :attributes

  def call
    challenge.update!(attributes)
    challenge
  end
end

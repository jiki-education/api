class ExerciseSubmission::File::GenerateDigest
  include Mandate

  initialize_with :content

  def call = XXhash.xxh64(sanitized_content).to_s

  private
  memoize
  def sanitized_content
    content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
  end
end

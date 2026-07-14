class ExerciseSubmission::UpdateProgressionScores
  include Mandate

  initialize_with :submission, :progression_scores

  def call
    submission.update!(progression_scores: sanitized_progression_scores)
  end

  private
  # Analytics data from the frontend "stuckometer". Patching it must never
  # fail a request, so anything that isn't a non-empty JSON object of integer
  # values is silently normalized to nil rather than raising.
  memoize
  def sanitized_progression_scores
    scores = progression_scores
    scores = scores.to_unsafe_h if scores.respond_to?(:to_unsafe_h)
    return nil unless scores.is_a?(Hash)

    scores = scores.to_h
    return nil if scores.empty?
    return nil unless scores.values.all?(Integer)

    scores
  end
end

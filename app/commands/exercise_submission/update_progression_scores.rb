class ExerciseSubmission::UpdateProgressionScores
  include Mandate

  initialize_with :submission, :progression_scores

  def call
    submission.update!(progression_scores: sanitized_progression_scores)
  end

  private
  # Analytics data from the frontend "stuckometer", shaped as
  # { v: 1, score: 27, metrics: { scenarios: 10, used_loop: 10, ... } }.
  # Patching it must never fail a request, so anything that doesn't match
  # that shape (integer v and score, plus a hash of integer metrics) is
  # silently normalized to nil rather than raising. Unknown top-level keys
  # are dropped.
  memoize
  def sanitized_progression_scores
    scores = to_hash(progression_scores)
    return nil unless scores

    version = scores["v"]
    score = scores["score"]
    metrics = to_hash(scores["metrics"])

    return nil unless version.is_a?(Integer)
    return nil unless score.is_a?(Integer)
    return nil unless metrics&.values&.all?(Integer)

    { "v" => version, "score" => score, "metrics" => metrics }
  end

  def to_hash(value)
    value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
    return nil unless value.is_a?(Hash)

    value.to_h.transform_keys(&:to_s)
  end
end

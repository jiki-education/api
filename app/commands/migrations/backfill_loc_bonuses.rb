# One-off backfill, run from a migration and not used by the app. Lives under
# Migrations:: so it doesn't sit alongside the commands the app actually calls.
#
# Backfills bonus_completed_at for exercises whose bonus is purely a
# lines-of-code target, by re-scoring each user's most recent submission.
#
# Bonus passes were never recorded (they lived only in the browser's test-suite
# result), but the code that earned them is stored, so an LOC-only bonus can be
# recovered after the fact.
#
# Javascript only: the limits differ per language, and python users are skipped
# rather than scored against the wrong target.
#
# LOC_LIMITS is a snapshot of the front-end curriculum taken at backfill time -
# deliberately frozen here rather than read from the curriculum package, both
# because the API can't import it and because a migration must keep scoring the
# same way however the curriculum moves afterwards.
#
# Exercises whose bonus scenarios carry a check we can't evaluate from stored
# code alone (a nesting-depth or behavioural assertion) are excluded entirely -
# passing the LOC target wouldn't prove they passed the bonus. As of this
# snapshot that's: acronym, adventures-in-poetry, digital-root, isbn-verifier,
# leap, look-around and maze-turn-around. anagram, smashing-blocks, word-count
# and wordle-process-game have bonuses that aren't LOC-based at all.
class Migrations::BackfillLocBonuses
  include Mandate

  queue_as :default

  # Exercise slug => max lines of code.
  LOC_LIMITS = {
    "alphanumeric" => 42,
    "driving-test" => 12,
    "even-or-odd" => 6,
    "formal-dinner" => 9,
    "guest-list" => 9,
    "hamming" => 11,
    "lower-pangram" => 16,
    "lunchbox" => 16,
    "matching-socks" => 29,
    "niche-named-party" => 20,
    "raindrops" => 16,
    "sign-price" => 9,
    "three-letter-acronym" => 3,
    "tile-search" => 8,
    "two-fer" => 6
  }.freeze

  # Guards against awarding a bonus for a stub. An empty or near-empty file
  # trivially satisfies a max-lines target without solving anything, and the
  # required scenarios passing is judged by completed_at, which a lesson can
  # carry from a curriculum change rather than a real solve.
  MIN_LINES = 3

  BATCH_SIZE = 500

  LANGUAGE = "javascript".freeze

  def call
    scope.includes(lesson: :level).find_in_batches(batch_size: BATCH_SIZE) do |batch|
      submissions = latest_submissions_for(batch)

      batch.each do |user_lesson|
        backfill!(user_lesson, submissions[user_lesson.id])
      end
    end

    Rails.logger.info(
      "BackfillLocBonuses: awarded #{counts[:awarded]}, " \
      "skipped #{counts[:missing_files]} with unreadable files"
    )

    counts
  end

  private
  def scope
    UserLesson.completed.
      where(bonus_completed_at: nil).
      joins(:lesson).
      where(lesson: { slug: LOC_LIMITS.keys })
  end

  def backfill!(user_lesson, submission)
    return unless submission
    return if python?(user_lesson)

    source = source_for(submission)
    return if source.nil?

    lines = ExerciseSubmission::CountLinesOfCode.(source, LANGUAGE)
    return if lines < MIN_LINES
    return if lines > limit_for(user_lesson)

    # Dated to the submission rather than now: this is when the bonus was
    # actually earned.
    user_lesson.update!(bonus_completed_at: submission.created_at)
    counts[:awarded] += 1
  end

  # Two queries per batch: the latest submission id per user_lesson, then those
  # submissions with their files' blobs. Loading them per row would be an N+1
  # across every completed lesson in the course.
  def latest_submissions_for(batch)
    latest_ids = ExerciseSubmission.
      where(context_type: "UserLesson", context_id: batch.map(&:id)).
      group(:context_id).
      maximum(:id).
      values

    ExerciseSubmission.where(id: latest_ids).
      includes(files: { content_attachment: :blob }).
      index_by(&:context_id)
  end

  def source_for(submission)
    submission.files.map { |file| file.content.download }.join("\n")
  rescue ActiveStorage::FileNotFoundError
    # A missing blob can't be re-scored. Skip rather than guess - and count
    # rather than report each one, since a backfill over every historical
    # submission would otherwise bury Sentry in individual events.
    counts[:missing_files] += 1
    nil
  end

  memoize
  def counts = { awarded: 0, missing_files: 0 }

  def limit_for(user_lesson) = LOC_LIMITS.fetch(user_lesson.lesson.slug)

  # The limits differ per language, and these are the javascript ones, so a
  # user who chose python is left alone rather than scored against the wrong
  # target. An unset language is treated as javascript: it's the default, and
  # a user who never chose can't have submitted python.
  def python?(user_lesson)
    languages[[user_lesson.user_id, user_lesson.lesson.level.course_id]] == "python"
  end

  # One query for every relevant user's chosen language, rather than one per row.
  memoize
  def languages
    UserCourse.where(user_id: scope.select(:user_id)).
      pluck(:user_id, :course_id, :language).
      to_h { |user_id, course_id, language| [[user_id, course_id], language] }
  end
end

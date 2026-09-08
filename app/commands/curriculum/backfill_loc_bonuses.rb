# Backfills bonus_completed_at for exercises whose bonus is purely a
# lines-of-code target, by re-scoring each user's most recent submission.
#
# Bonus passes were never recorded (they lived only in the browser's test-suite
# result), but the code that earned them is stored, so an LOC-only bonus can be
# recovered after the fact.
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
class Curriculum::BackfillLocBonuses
  include Mandate

  # Exercise slug => max lines of code, per language.
  LOC_LIMITS = {
    "alphanumeric" => { javascript: 42, python: 35 },
    "driving-test" => { javascript: 12, python: 8 },
    "even-or-odd" => { javascript: 6, python: 4 },
    "formal-dinner" => { javascript: 9, python: 6 },
    "guest-list" => { javascript: 9, python: 6 },
    "hamming" => { javascript: 11, python: 8 },
    "lower-pangram" => { javascript: 16, python: 10 },
    "lunchbox" => { javascript: 16, python: 13 },
    "matching-socks" => { javascript: 29, python: 67 },
    "niche-named-party" => { javascript: 20, python: 14 },
    "raindrops" => { javascript: 16, python: 16 },
    "sign-price" => { javascript: 9, python: 6 },
    "three-letter-acronym" => { javascript: 3, python: 2 },
    "tile-search" => { javascript: 8, python: 5 },
    "two-fer" => { javascript: 6, python: 6 }
  }.freeze

  # Guards against awarding a bonus for a stub. An empty or near-empty file
  # trivially satisfies a max-lines target without solving anything, and the
  # required scenarios passing is judged by completed_at, which a lesson can
  # carry from a curriculum change rather than a real solve.
  MIN_LINES = 3

  BATCH_SIZE = 500

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

    source = source_for(submission)
    return if source.nil?

    lines = ExerciseSubmission::CountLinesOfCode.(source, language_for(user_lesson))
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

  def limit_for(user_lesson)
    limits = LOC_LIMITS.fetch(user_lesson.lesson.slug)
    language = language_for(user_lesson)

    # No language chosen means we can't tell which limit applied, so use the
    # stricter of the two - never award a bonus that might not have been earned.
    return limits.values.min if language.nil?

    limits.fetch(language.to_sym)
  end

  def language_for(user_lesson)
    languages[[user_lesson.user_id, user_lesson.lesson.level.course_id]]
  end

  # One query for every relevant user's chosen language, rather than one per row.
  memoize
  def languages
    UserCourse.where(user_id: scope.select(:user_id)).
      pluck(:user_id, :course_id, :language).
      to_h { |user_id, course_id, language| [[user_id, course_id], language] }
  end
end

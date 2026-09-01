# Adds the `adventures-in-poetry` exercise to the end of the `advanced-loops`
# level (after `digital-root`) and resurfaces it for users who had already
# completed that level.
#
# The seeds create the lesson too (it lives in curriculum.json), so which of the
# two runs first doesn't matter - Curriculum::AppendLesson is idempotent and
# will just do the user reconciliation if the lesson is already there.
class AppendAdventuresInPoetryLesson < ActiveRecord::Migration[8.0]
  def up
    level = Level.find_by(slug: 'advanced-loops')
    return unless level

    Curriculum::AppendLesson.(
      level,
      {
        uuid: '0f457c0a-2464-4741-990a-9f885c838160',
        slug: 'adventures-in-poetry',
        type: 'exercise'
      },
      reopen_completed: true
    )
  end

  def down
    # Not reversible: we can't tell which levels were completed before the
    # reopen, so re-completing them would be guesswork.
  end
end

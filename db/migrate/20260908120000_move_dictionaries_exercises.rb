# Moves four exercises out of `changing-dictionaries`: `rna-transcription` to
# `methods-and-properties`, and `protein-translation`, `spotify` and
# `llm-response` to `dictionaries`. They keep their uuids (and so their
# UserLesson rows), so this is a move rather than an append.
#
# Curriculum::MoveLesson does the user reconciliation: it completes
# `changing-dictionaries` for anyone whose only-remaining lessons were the ones
# leaving, backfills destination UserLevels for users who already progressed on
# a moved lesson, and - with reopen_completed - resurfaces the destinations for
# users who had already finished them.
#
# The seeds move the lessons too (they live in curriculum.json), so which of the
# two runs first doesn't matter; MoveLesson still does the reconciliation.
class MoveDictionariesExercises < ActiveRecord::Migration[8.0]
  MOVES = {
    'rna-transcription' => 'methods-and-properties',
    'protein-translation' => 'dictionaries',
    'spotify' => 'dictionaries',
    'llm-response' => 'dictionaries'
  }.freeze

  def up
    MOVES.each do |lesson_slug, level_slug|
      lesson = Lesson.find_by(slug: lesson_slug)
      level = Level.find_by(slug: level_slug)
      next unless lesson && level

      Curriculum::MoveLesson.(lesson, level, reopen_completed: true)
    end
  end

  def down
    # Not reversible: we can't tell which levels were completed before the
    # reopen, so re-completing them would be guesswork.
  end
end

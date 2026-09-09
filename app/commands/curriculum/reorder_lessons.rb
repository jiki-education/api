# Safely reorder the lessons within a level, reconciling existing users.
#
# Reordering is the one curriculum edit with no safe hand-rolled form: it needs
# no UserLesson or UserLevel changes at all, which makes it look free, but it
# silently strands anyone parked on a lesson that moved backwards (see
# Curriculum::ReleaseStrandedLessonPointers for the mechanics). Call this rather
# than reassigning positions directly.
#
# Takes the level's lesson slugs in their new order - all of them, so a reorder
# is always expressed as the complete intended ordering rather than a diff.
#
# Editing db/seeds/curriculum.json does the same reordering on the next deploy,
# so Level::CreateAllFromJson runs the same reconciliation itself; this command
# is for migrations that reorder without going through the seeds.
class Curriculum::ReorderLessons
  include Mandate

  initialize_with :level, :ordered_slugs

  # (level_id, position) is unique, so positions are shifted clear before the
  # final ones are assigned - mirroring Level::CreateAllFromJson.
  POSITION_OFFSET = 100_000

  def call
    ActiveRecord::Base.transaction do
      validate_ordering!
      reorder!
      Curriculum::ReleaseStrandedLessonPointers.(level)
    end
  end

  private
  def validate_ordering!
    return if ordered_slugs.sort == existing_slugs.sort

    raise InvalidLessonOrderingError,
      "Ordering must list every lesson on #{level.slug} exactly once " \
      "(got #{ordered_slugs.inspect}, level has #{existing_slugs.inspect})"
  end

  memoize
  def existing_slugs = level.lessons.pluck(:slug)

  def reorder!
    level.lessons.reorder(nil).update_all("position = position + #{POSITION_OFFSET}")

    ordered_slugs.each_with_index do |slug, index|
      level.lessons.reorder(nil).where(slug:).update_all(position: index + 1)
    end
  end
end

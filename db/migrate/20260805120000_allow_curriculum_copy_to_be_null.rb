class AllowCurriculumCopyToBeNull < ActiveRecord::Migration[8.1]
  # Step one of a two-part removal. The application has stopped reading and
  # writing this copy (see the ignored_columns declarations on the models), but
  # the columns stay for now so that instances still running the old code keep
  # working through the rolling deploy. A follow-up migration drops them once
  # this has fully rolled out.
  #
  # Relaxing NOT NULL is what lets the new code insert rows without supplying
  # copy it no longer has.
  COLUMNS = {
    lessons: %i[title description],
    levels: %i[title description milestone_summary milestone_content],
    concepts: %i[title description],
    courses: %i[title description],
    challenges: %i[title description],
    badges: %i[name description],
    level_translations: %i[title description milestone_summary milestone_content],
    badge_translations: %i[name description fun_fact],
    lesson_translations: %i[title description]
  }.freeze

  def change
    COLUMNS.each do |table, columns|
      columns.each { |column| change_column_null table, column, true }
    end

    # Exercise lessons now carry no data at all. Rails' serialized type writes
    # NULL for a value matching the coder's default ({}), so the column has to
    # accept it; Lesson#data still reads it back as {}.
    change_column_null :lessons, :data, true
  end
end

require "csv"

namespace :posthog do
  desc "Dump curriculum tables to CSV for upload to PostHog Data Warehouse"
  task dump_warehouse: :environment do
    output_dir = Rails.root.join("tmp/posthog")
    FileUtils.mkdir_p(output_dir)

    dump_to_csv(output_dir.join("lessons.csv"), Lesson.all, %i[id slug title type position level_id])
    dump_to_csv(output_dir.join("levels.csv"),  Level.all,  %i[id slug title position course_id])
    dump_to_csv(output_dir.join("projects.csv"), Project.all, %i[id slug title exercise_slug])

    puts "CSVs written to #{output_dir}"
    puts "Next: upload them to Cloudflare R2 and re-sync the linked sources in PostHog."
  end

  def dump_to_csv(path, scope, columns)
    CSV.open(path, "w") do |csv|
      csv << columns
      scope.find_each do |record|
        csv << columns.map { |col| record.public_send(col) }
      end
    end
    puts "Wrote #{scope.count} rows to #{path}"
  end
end

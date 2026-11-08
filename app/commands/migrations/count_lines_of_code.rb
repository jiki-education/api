# Counts a submission's lines of code the way the front-end interpreters do,
# so LOC-based bonuses score the same here as they did in the browser.
#
# Mirrors countLinesOfCode in interpreters/src/{javascript,python}/
# assertion-helpers.ts, as it stood when the backfill ran - a snapshot for
# Migrations::BackfillLocBonuses, not a live mirror to keep in step.
class Migrations::CountLinesOfCode
  include Mandate

  initialize_with :source, :language

  def call
    language.to_s == "python" ? count_python : count_javascript
  end

  private
  # `} else {` and a `}` / `else {` split across two lines express the same
  # structure, so the joint costs one line either way.
  BRACE_CONTINUATION_KEYWORDS = /\A(?:else|catch|finally)\b/

  def count_python
    lines.count { |line| line.present? && !line.start_with?("#") }
  end

  def count_javascript
    counted = javascript_counted_lines

    counted.reject.with_index do |line, idx|
      line == "}" && counted[idx + 1]&.match?(BRACE_CONTINUATION_KEYWORDS)
    end.count
  end

  def javascript_counted_lines
    in_multi_line_comment = false

    [].tap do |counted|
      lines.each do |line|
        next if line.blank?

        in_multi_line_comment = true if line.include?("/*")
        if in_multi_line_comment
          in_multi_line_comment = false if line.include?("*/")
          next
        end

        next if line.start_with?("//")

        counted << line
      end
    end
  end

  memoize
  def lines = source.to_s.split("\n").map(&:strip)
end

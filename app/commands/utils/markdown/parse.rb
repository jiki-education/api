class Utils::Markdown::Parse
  include Mandate

  initialize_with :markdown

  def call
    return "" if markdown.blank?

    sanitized_html
  end

  private
  memoize
  def sanitized_html
    # Remove HTML comments for security hygiene
    # Note: We trust admin-provided content, so we don't escape HTML
    remove_comments = Loofah::Scrubber.new do |node|
      node.remove if node.name == "comment"
    end

    Loofah.fragment(raw_html).
      scrub!(remove_comments).
      to_s
  end

  memoize
  def raw_html
    # Parse markdown and render to HTML using CommonMarker
    Commonmarker.to_html(markdown, options: {
      parse: { smart: true },
      render: { unsafe: true }
    })
  end
end

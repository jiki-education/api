class EmailTemplate::GenerateSummary
  include Mandate

  def call
    EmailTemplate.
      group(:type, :slug).
      order(:type, :slug).
      pluck(:type, :slug, Arel.sql("array_agg(locale ORDER BY locale)")).
      map { |type, slug, locales| { type:, slug:, locales: } }
  end
end

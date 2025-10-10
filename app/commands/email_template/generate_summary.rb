class EmailTemplate::GenerateSummary
  include Mandate

  def call
    EmailTemplate.
      select(:type, :slug, :locale).
      distinct.
      order(:type, :slug, :locale).
      group_by { |template| [template.type, template.slug] }.
      map do |(type, slug), templates|
        {
          type: type,
          slug: slug,
          locales: templates.map(&:locale).sort
        }
      end
  end
end

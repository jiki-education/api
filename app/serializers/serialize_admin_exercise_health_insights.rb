class SerializeAdminExerciseHealthInsights
  include Mandate

  initialize_with :insights

  def call
    insights.map do |insight|
      {
        type: insight[:type],
        severity: insight[:severity],
        lesson_id: insight[:lesson_id],
        slug: insight[:slug],
        title: insight[:title],
        message: insight[:message],
        value: insight[:value]
      }
    end
  end
end

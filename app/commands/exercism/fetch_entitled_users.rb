class Exercism::FetchEntitledUsers
  include Mandate

  def call
    response = HTTParty.get(
      "#{Jiki.config.exercism_base_url}/api/v2/jiki/entitled_users",
      headers: { "Authorization" => "Bearer #{Jiki.secrets.exercism_api_key}" }
    )

    raise FetchExercismUserStatusesError, "Exercism returned #{response.code}: #{response.body}" unless response.success?

    {
      'insider_ids' => Array.wrap(response.parsed_response['insider_ids']).map(&:to_s),
      'bootcamp_member_ids' => Array.wrap(response.parsed_response['bootcamp_member_ids']).map(&:to_s)
    }
  end
end

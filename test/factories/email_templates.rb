FactoryBot.define do
  factory :email_template do
    type { :level_completion }
    slug { "level-1" }
    locale { "en" }
    subject { "Congratulations {{ user.name }}!" }
    body_mjml do
      <<~MJML
        <mj-section background-color="#ffffff">
          <mj-column>
            <mj-text>
              <h1>Congratulations, {{ user.name }}!</h1>
            </mj-text>
            <mj-text>
              <p>You completed {{ level.title }}!</p>
            </mj-text>
          </mj-column>
        </mj-section>
      MJML
    end
    body_text { "Congratulations, {{ user.name }}! You completed {{ level.title }}!" }

    trait :hungarian do
      locale { "hu" }
      subject { "Gratulálunk {{ user.name }}!" }
      body_mjml do
        <<~MJML
          <mj-section background-color="#ffffff">
            <mj-column>
              <mj-text>
                <h1>Gratulálunk, {{ user.name }}!</h1>
              </mj-text>
              <mj-text>
                <p>Teljesítetted: {{ level.title }}!</p>
              </mj-text>
            </mj-column>
          </mj-section>
        MJML
      end
      body_text { "Gratulálunk, {{ user.name }}! Teljesítetted: {{ level.title }}!" }
    end
  end
end

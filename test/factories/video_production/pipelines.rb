FactoryBot.define do
  factory :video_production_pipeline, class: 'VideoProduction::Pipeline' do
    title { "Test Pipeline" }
    version { "1.0" }
    config do
      {
        'storage' => {
          'bucket' => 'jiki-videos-test',
          'prefix' => 'pipelines/'
        },
        'workingDirectory' => './output'
      }
    end
    metadata do
      {
        'totalCost' => 0,
        'estimatedTotalCost' => 0,
        'progress' => {
          'completed' => 0,
          'in_progress' => 0,
          'pending' => 0,
          'failed' => 0,
          'total' => 0
        }
      }
    end
  end
end

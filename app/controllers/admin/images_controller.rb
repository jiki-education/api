class Admin::ImagesController < Admin::BaseController
  def create
    image_file = params[:image]

    return render json: { error: 'No image file provided' }, status: :unprocessable_entity unless image_file.respond_to?(:read)

    result = Images::Upload.(
      image_file.read,
      image_file.original_filename
    )

    render json: { url: result[:url] }, status: :created
  rescue ImageFileTooLargeError, InvalidImageTypeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end

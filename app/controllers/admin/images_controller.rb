class Admin::ImagesController < Admin::BaseController
  def create
    image_file = params[:image]

    return render_422(:no_image_provided) unless image_file.respond_to?(:read)

    result = Images::Upload.(
      image_file.read,
      image_file.original_filename
    )

    render json: { url: result[:url] }, status: :created
  rescue ImageFileTooLargeError
    render_422(:file_too_large)
  rescue InvalidImageTypeError
    render_422(:invalid_image_type)
  end
end

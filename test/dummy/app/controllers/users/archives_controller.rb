class Users::ArchivesController < UsersController
  def show
    @archive = Archive.find(params[:id])
  end
  
  def index
    @archives = Archive.all
  end
end 
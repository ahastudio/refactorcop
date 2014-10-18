require 'zip'

class RubocopWorker
  include Sidekiq::Worker

  sidekiq_options retry: true

  #start rubocop for a given repo
  def perform(project_id, force_run: false)

    project = Project.find(project_id)

    #exit if the project is not existing
    if project.nil?
      Rails.logger.warning "Project ##{project_id} not found!"
      return nil
    end

    #check wether the project is updated since last run
    if !project.new_commits? && !force_run
      Rails.logger.info "Project ##{project_id} #{project.full_name} hasn't been updated, *noop*"
      return nil
    end

    Rails.logger.info "Project ##{project_id} #{project.full_name} fetching project zipfile"


    ActiveRecord::Base.transaction do
      project.source_files.destroy_all

      Tempfile.create(["#{project.username}-#{project.name}",".zip"], :encoding => 'ascii-8bit') do |file|
        #grab the repo zipfile
        HTTPClient.get_content(project.download_zip_url) { |chunk| file.write(chunk) }

        #unzip the file
        begin
          Zip::File.open_buffer(file,) do |zip_file|
            # Handle entries one by one
            zip_file.glob('**/*.rb').each do |entry|
              next if entry.nil?
              puts "Extracting #{entry.name}"
              SourceFile.create(project: project,
                                content: entry.get_input_stream.read,
                                path: entry.name)

            end
          end
        rescue ArgumentError => e
          unless e.message =~ /wrong number of arguments/
            raise e
          end
        ensure
          Rails.logger.info "Project ##{project_id} #{project.full_name} zipfile processed"
        end

      end

    end

    #run rubocop

    #capture json output

    #process json output

  end
end
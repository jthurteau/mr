## 
# Encapsulates installer management for mr
#

module Installer
  # require 'file/utils'
#  require_relative 'file/mirror'
  extend self

  @enabled = false

  @install_files = [
    'mr_rogers.rb', 
    'mr_rogers',
    '+license_ident.yaml',
    '+puppet.yaml',
    '+vagrant.yaml',
    '+local-dev.example.project.yaml',
    '+facts.example.yaml',
  ]

  @install_global_files = [ 
  # /. means non-recursive (shallow) 
  # /? means recursive, but only if matching an entry in the stack (a.yaml and a/*)
  # otherwise entries are recursive and non-conditional
    'bash/.',
    'bash/?',
    'facts/?',
    'manifests/?',
    #'manifests/global.pp',
    'templates/?',
    'templates/gitignore.example.erb',
    'templates/hiera.erb',
  ]

  def self.enable()
    @enabled = true
  end

  def self.prep()
    temp_path = FilePaths::temp_path()
    mirror_path = "#{Mr::active_path()}/#{temp_path}ext/"
    import_path = "#{Mr::active_path()}/#{temp_path}imp/"
    FileUtils.rm_r(mirror_path, {:force => true}) if (File.directory?(mirror_path))
    FileManager::path_ensure(mirror_path, FileManager::allow_dir_creation?) #"Building puppeteer mirror...")
    FileManager::path_ensure("#{Mr::active_path()}/import", Vuppeteer::allow_dir_creation?)
    FileManager::import_files().each do |i|
    if (i.include?(' AS '))
        i_parts = i.split(' AS ')
        import_source = i_parts[0]
        import_as = i_parts[1]
    else
        import_source = i
        import_as = File.basename(i)
    end
    FileManager::import(import_source, "#{import_path}#{import_as}")
    end
    FileManager::mirror(FileManager::install_files(), mirror_path)
    FileManager::mirror(FileManager::install_global_files(), mirror_path, 'global.')
  end

  def self.install_files
    return @install_files
  end

#################################################################
  private
#################################################################

  # def self.global_ensure() #TODO rename these to import files? clean up external/global distinction
  #   #TODO also support the same + mode as install_files? right now it looks like it is default behavior
  #   active = Mr::active_path()
  #   global = Puppeteer::external? ? Mr::path() : "#{active}/global."
  #   list = Puppeteer::enforce_enumerable(Vuppeteer::get_fact('global_files', []))
  #   list.each do |f|
  #     base_path = "#{active}/" + File.dirname(f)
  #     self.path_ensure(base_path, self.allow_dir_creation?)
  #     missing_text = "Error: Missing external file #{f}, not available externally"
  #     if (!File.exist?("#{active}/#{f}"))
  #       global_f = Puppeteer::external? ? "#{global}/#{f}" : "#{global}#{f}"
  #       if File.exist?(global_f)
  #         Puppeteer::say("Migrating external file #{f}", 'prep')
  #         FileUtils.cp(global_f, "#{active}/#{f}")  if File.exist?(global_f)
  #       else 
  #         Puppeteer::say(missing_text, 'prep')
  #         #TODO setup a trigger to stop install in this case
  #         #Puppeteer::shutdown(missing_text) if !File.exist?(global_f)
  #       end
  #     end
  #   end
  # end

end
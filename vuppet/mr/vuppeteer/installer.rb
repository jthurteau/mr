## 
# Encapsulates installer management for mr
#

module Installer
  extend self

  @install_files = [
    'mr_rogers.rb', 
    'mr_rogers',
    '+el.yaml',
    '+puppet.yaml',
    '+vagrant.yaml',
    '+local-dev.example.vuppeteer.yaml',
    '+example.vuppeteer.yaml',
  ]

  @install_global_files = [ 
  # /. means all files (not sub-folders) non-recursive (shallow) 
  # /? means recursive, but only if matching an entry in the stack (a.yaml and a/*)
  # otherwise entries are recursive and non-conditional
    'bash/.',
    'bash/?',
    'facts/?',
    'hiera/?',
    'manifests/?',
    'templates/?',
    'templates/gitignore.example.erb',
    'templates/hiera.erb',
  ]

  def self.prep()
    Vuppeteer::shutdown('attempting install::prep', -1)
    mirror_path = "#{Mr::active_path()}/#{FileManager::path(:temp)}ext/"
    import_path = "#{Mr::active_path()}/#{FileManager::path(:temp)}imp/"
    FileUtils.rm_r(mirror_path, {:force => true}) if (File.directory?(mirror_path))
    FileManager::path_ensure(mirror_path, FileManager::allow_dir_creation?) #"Building vuppeteer mirror...")
    FileManager::path_ensure("#{Mr::active_path()}/import", Vuppeteer::allow_dir_creation?)
    Vuppeteer::import_files().each do |i|
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
    #TODO
    #self._external_ensure()
  end

  def self.install_files
    return @install_files
  end

#################################################################
  private
#################################################################

  ##
  # copies files from the external provisioner, but makes them project files (not "global.*")
  # def self.external_ensure() #TODO rename these to import files? clean up external/global distinction
  #   #TODO also support the same + mode as install_files? right now it looks like it is default behavior
  #   active = Mr::active_path()
  #   global = Vuppeteer::external? ? Mr::path() : "#{active}/global."
  #   list = MrUtils::enforce_enumerable(Vuppeteer::get_fact('global_files', []))
  #   list.each do |f|
  #     base_path = "#{active}/" + File.dirname(f)
  #     self.path_ensure(base_path, self.allow_dir_creation?)
  #     missing_text = "Error: Missing external file #{f}, not available externally"
  #     if (!File.exist?("#{active}/#{f}"))
  #       global_f = Vuppeteer::external? ? "#{global}/#{f}" : "#{global}#{f}"
  #       if File.exist?(global_f)
  #         Vuppeteer::say("Migrating external file #{f}", :prep)
  #         FileUtils.cp(global_f, "#{active}/#{f}")  if File.exist?(global_f)
  #       else 
  #         Vuppeteer::say(missing_text, :prep)
  #         #TODO setup a trigger to stop install in this case
  #         #Vuppeteer::shutdown(missing_text) if !File.exist?(global_f)
  #       end
  #     end
  #   end
  # end

end
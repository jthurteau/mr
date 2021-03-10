## 
# Generates bash scripts from erb files for MrRogers
#

module FileErBash
  require 'erb'

  extend self

  @internal_only = false

  def self.script(script_name, view = nil)
    type = view ? 'erb' : 'sh'
    base_path = Mr::active_path()
    #TODO filter out funny path navigations in script_name
    #TODO error when if statement is the first line? error when first line is blank?
    file_name = "#{script_name}.#{type}"
    effective_path = FileManager::bash_path(file_name)
    if (!@internal_only && !File.readable?("#{effective_path}/#{file_name}"))
#      Puppeteer::say("Loaded external script #{script_name}...", 'prep')
      effective_path = Mr::path(effective_path) #'bash') #TODO eventually use an absolute path rather than rely on effective_path
      Puppeteer::report('bash',script_name, 'external')
    else
      Puppeteer::report('bash',script_name, 'internal')
    end #TODO add error handling for the not globally available case
    raise "Unable to load script #{file_name}  #{effective_path}/#{file_name}" if !File.readable?("#{effective_path}/#{file_name}")
    contents = File.read("#{effective_path}/#{file_name}")
    # if(contents.include?("\r"))

    #   print(['no',contents.include?("\r"),contents.include?("\r\n")]);
    #   exit
    # end
    return contents if(!view)
    #TODO catch and handle parse errors
    return ERB.new(contents).result(view);
  end
  
  #################################################################
    private
  #################################################################
    
  end
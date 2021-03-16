## 
# Generates bash scripts from erb files for MrRogers
#

module ErBash
  require 'erb'

  extend self

  @internal_only = false

  def self.script(script_name, view = nil)
    type = view ? 'erb' : 'sh'
    base_path = Mr::active_path()
    #TODO filter out funny path navigations in script_name
    #TODO error when if statement is the first line? error when first line is blank?
    file_name = "#{script_name}.#{type}"
    effective_path = FileManager::path(:bash, file_name)
    if (!@internal_only && !File.readable?("#{effective_path}/#{file_name}"))
#      Vuppeteer::say("Loaded external script #{script_name}...", 'prep')
      effective_path = Mr::path(effective_path) #'bash') #TODO eventually use an absolute path rather than rely on effective_path
      Vuppeteer::report('bash',script_name, 'external')
    else
      Vuppeteer::report('bash',script_name, 'internal')
    end #TODO add error handling for the not globally available case
    raise "Unable to load script #{file_name}  #{effective_path}/#{file_name}" if !File.readable?("#{effective_path}/#{file_name}")
    contents = File.read("#{effective_path}/#{file_name}")
    # if(contents.include?("\r"))

    #   Vuppeteer::trace('no',contents.include?("\r"),contents.include?("\r\n"));
    #   exit
    # end
    return contents if(!view)
    #TODO catch and handle parse errors
    return ERB.new(contents, nil, '-').result(view);
  end
  
  #################################################################
    private
  #################################################################
    
  end
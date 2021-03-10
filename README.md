# Mr
Developer tool for Environment Replication leveraging a Vagrant/Puppet/Fedora stack for VM provisioning.

## Current Status

Mr is being ported from a private 0.x development build to a public open-source 1.x build. 0.x began as a git-gist a bit over two years ago (https://gist.github.com/jthurteau/3c3d8e15208d93c0cf28cc2148c91b0b), it's undergone heavy development as a practical tool since then but needs drastic refactoring (because I'm really not a Ruby developer).

I'm hoping to complete the initial refactor (meaning the public code will be a usable tool again) by the end of March 2021.

## Getting Started

This documentation covers using Mr to:

 - reproduce a sandbox Virtual Machine (VM) provided with a project
 - make host envionment (e.g. files) available in a sandbox VM 
 - make environment from the sandbox VM available to the host
 - set up a project with an automatically repoducable sandbox VM
 - develop recipes for sandbox VMs that translate into production environments

 If you are looking for common troubleshooting steps, also consult: [Common Issues](https://github.com/jthurteau/mr/wiki/Common-Provisioning-Issues-\(and-solutions\))

### Building a project that uses MrRogers

*under construction*

## Mr options

A hash of configuration options can be passed into the inital Mr::vagrant call from the Vagrantfile, these are generally intended to be things that should be disclosed to anyone running the build and not burried in the details of the project recipies. 

Some of these options that can only be set in this way, including:

 - root_path
   - Defaults to '.', being a relative reference to the folder containing the Vagrantfile
   - This sets the "project root" for Mr, which is the base path for all following path calculations
   - This setting cannot traverse up the file tree, and is limited to the folder containing the Vagrantfile and its sub-directories
 - mr_path
   - Defaults to './vuppet', being a relative reference to a peer folder to the Vagrantfile
   - This sets the "active path" for Mr which is effectively the default path for all host operations
   - This must be within the 'allowed_read_path'
 - allowed_read_path
   - Defaults to \['../', '~/.mr/']
   - One (string) or more (array of strings) paths that Mr is allowed to read from
   - Any files to be shared with the sandbox VM should be in the allowed_read_path, otherwise Mr will abort
 - allowed_write_path
   - Defaults to allow './vuppet'
   - One (string) or more (array of strings) paths that Mr is allowed to write to
   - Any files to be altered on the host should be in the allowed_write_path, otherwise Mr will abort
 - target_manifest
   - File in the active_path to write a single compiled Puppet manifest (.pp) representing what will be sent to the sandbox VM
   - defaults to './vuppet/local-dev.pp'
 - localize_token
   - String prefix for files not intended to be commited back to the project's repo
   - Defaults to 'local-dev.', e.g. local-dev.pp is the default manifest built to direct Puppet how to provision the sandbox VM, but that file may contain local and/or sensitive values so it is excluded from the repo
 - override_token
   - String prefix for files that start with the 'localize_token', but are "samples" intended to be included in the repo
   - Defaults to 'example.', e.g. local-dev.example.project.yaml is an example of what you might put into the local copy of local-dev.project.yaml file.
 - load_local_facts
   - String or Boolean indicating whether or not to use a "local facts file" as part of the build process.
   - Defaults to './vuppet/local-dev.project.yaml', assuming the localize_token is 'local-dev.' and active_path is './vuppet'
   - must be in allowed_read_path

Other options can be passed in the Vagrantfile, or set during the initialization process from configuration files. Generally the consideration behind where they should be set hinges on making it clear how the project is built without an overwhelming level of detail up-front. 

 - facts
   - Hash of values constituting parameters to building the sandbox VM, or string name (not including .yaml) for the project build configuration.
   - These values will be directly available to both Mr and Puppet
   - If the value is a hash, the default configuration also loads an optional ./vuppet/project.yaml
   - additional values from other .yaml files in the active path are also be merged into the facts depending on configuration
 - generated
   - Hash of facts to be generated (e.g. by randomized methods)
   - See "Procedural Facts" for the configuration of these values
 - assert
   - Hash of facts and exact matching values that the build must generate to be considered valid
   - Also accepts a single String as shorthand for {'project_name' => '"string"'}
   - Asserts are a shorthand for configuration merged into 'require'
 - require
   - Array of facts that must exist or match an algorithm for the build to be considered valid
   - Each item may be a String, indicating the fact must not be 'nil' (undefined/null) or a Hash evaluated as if passed to 'assert' above, or an array in the format: \['"fact"', :match_type, \[optional_match_param]]
   - See "Build Validity" for information on match_types  
 - stack
   - List of token strings indicating what recipies Mr should look for in the active path. This informs both the process of building a sandbox VM and the process of installing a self-provisioning copy of Mr into a project
   - It is generally recommended to publish the stack for your project in the Vagrantfile options, but it may be declared in the project build configurationanywhere in the fact building process
 - load_developer_facts
   - String or Boolean indicating whether or not to use a "developer facts file" as part of the build process.
   - Defaults to '~/.mr/developer.yaml'
   - Cannot be accessed if not in allowed_read_path
 - load_stack_facts
   - Boolean, Defaults to true, set to false to disable loading any .yaml files from the '(\*.)facts' folders of active_path and/or "my_path". 
 - disable_hiera
   - Boolean, Defaults to false, set to true to disable Hiera for Puppet and any configuration from .yaml files from the '(\*.)hiera' folders of the active_path and/or "my_path". This also prevents Hiera from blocking matching .pp configuration files in the '*manifests' folders. See "Build Maturity" for more information.

### Build Validity

### Procedural Facts

## Build Maturity

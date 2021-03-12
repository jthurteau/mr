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

A hash of configuration options can be passed into the inital Mr::vagrant call from the Vagrantfile, these are generally intended to be things that should be disclosed to anyone running the build and not burried in the details of the project recipes. 

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
   - List of token strings indicating what recipes Mr should look for in the active path. This informs both the process of building a sandbox VM and the process of installing a self-provisioning copy of Mr into a project
   - It is generally recommended to publish the stack for your project in the Vagrantfile options, but it may be declared in the project build configurationanywhere in the fact building process
 - load_developer_facts
   - String or Boolean indicating whether or not to use a "developer facts file" as part of the build process.
   - Defaults to '~/.mr/developer.yaml'
   - Cannot be accessed if not in allowed_read_path
 - load_stack_facts
   - Boolean, Defaults to true, set to false to disable loading any .yaml files from the '(\*.)facts' folders of active_path and/or "my_path". 
 - disable_hiera
   - Boolean, Defaults to false, set to true to disable Hiera for Puppet and any configuration from .yaml files from the '(\*.)hiera' folders of the active_path and/or "my_path". This also prevents Hiera from blocking matching .pp configuration files in the '*manifests' folders. See "Build Maturity" for more information.
 - verbose
   - increases a variety of error outputs, and tends to increase verbosity to sub-components (e.g. Puppet)
 - debug
   - turns on verbosity and prevents a variety of outputs from being buffered by triggers 

### Build Validity

### Procedural Facts

## Build Maturity

## Mr Environment Replication Tools

### Project Repos

Project Repos are local or remote files (e.g. github repos) that are copied into the active_path (./vuppet) for use by the project being built in the guest vm. By default they are synced (copied) on the host filesystem every time Vagrant runs to a folder excluded from being commited back to the project's source repo (./vuppet/local-dev.repos). 

Project Repos can be set to sync to a different folder in the active_path by setting the "project_repo_path" fact. This facility is designed to copy files isolated to the local build (not shared back to the project's repo as part of the embedded distribution), so the destination for Project Repos should be set to a folder ignored by Git. 

For functionality that bundles local host files with your Mr intalled Mr provisioner, see "Imports" below.

They can be set to sync only on calling the 'repo-sync' provisioner (run automatically only once) by setting the "project_repo_autosync" fact to false. This is useful if you want to live-edit the copy in the active path and not at the original source, or if the copy process is lengthy.

Project Repos are declared in the 'project_repos' fact, which must be a single string, or array of strings. The strings must match the following formats:

\[repo_uri]
\[repo_uri#branch]
\[repo_uri] AS \[target-name]
\[repo_uri#branch] AS \[target-name]
\[readable/path]
\[readable/path] AS \[target-name]
\[multiple] OR \[paths] AS \[target-name]

- 'readable/path' must be in the host_reabable_path, which by default includes ../* and ~/.mr/*
- 'target-name' should be a single directory name (no sub/directories), this is the name of the sub-folder in \[active_path]/local-dev.tmp/imp that the imported file/directory on the host will be imported to.
- When multiple sources are identified, Mr will use the first one that exists
- When no target is specified, the "target" will be the last directory name in the path (ommitting ".git" if the source was a repo_uri)
- The "target" indicates the folder in local-dev.repos to copy the contents of the source to

Mr will throw a warning if specifying multiple paths with no explicit target since the auto-generated target is based on the matching path (which can lead to unpredictable behavior).

While primarily intended for use with actual git repos (or at least working-copies), project_repos can include any local file. A future version of Mr will also support arbirary remote files (e.g. RPMs)

### Provisioner Installation

Mr can copy itself into a project as packaged Vagrant provisioner. This is done by running Mr as an External Provisioner on the project, and provisioning with the mr-install provisioner. Mr will copy files from its my_path to the active_path, and perform other steps based on the project's configuration. The result should be a bundled provisioner that can be checked into the project's repo and the reproduced anywhere the project is checked out (provided Vagrant and Virtual Box are available).

#### Mirroring

Mr copies (mirrors) various files to a local_temp folder in the active_path every time Vagrant runs with an external Mr provisioner. These are for use in the Install process and include:

- \[active_path]/local-dev.tmp/ext (ruby scripts that make up Mr and various recipe files used for provisioning)
- \[active_path]/local-dev.tmp/imp (host files specified in the project configuration for mirroing into the active_path)

These include all the ruby scripts used to run Mr, any recipe files from the external provisioner matching the project's stack entries, and other core configuration files. Mirrored files will either replace or be added in a create-only manner to the active_path during install depending on configuration. Mr's ruby scripts always replace any existing copies (mr.rb is replaced, and mr/ is deleted and replaced). External recipes get copied to the active_path as "global recipes" (replacing all previous global.* folders). Other core files are copied in a create-only manner, unless configured otherwise. Use the 'install_files' fact to set what core configuration files mr will install. 

- They must be my_path relative paths, and 
- if the path is preceeded with a '+' it will copy in create-only manner, otherwise it will replace any existing file. 
- There is no need to specify 'mr.rb' or the 'mr' folder in 'install_files', as Mr will always insert them and they cannot be set to 'create-only'.
- Similarly, the built-in rules governing 'global*' folders cannot be replaced, but they can be supplimented with the 'install_global_files' fact.
- any paths specifed will copied recursively, unless
  - the path ends in '.' in which case its direct file children will be included, but not sub-folders
  - the path ends in '?' in which case it's direct file children and sub-folders will be copied if they start with a string matching one of the project's stack entries
- Mr applies all of these matches iteratively and after truncation, so files that match any criteria should be copied

#### Imports

Import files are copied from the local file system to a local_temp folder in the active_path for use by Mr during a "provisioner install". Unlike Project Repos:  

- Import files must be local, and 
- they are only copied when Mr is running as an external provisoiner, and
- there is no setting to disable the sync of import files.

Import files are copied from \[active_path]/local-dev.tmp/imp to \[active_path]/import during an Mr Install. In that process, any .git files in the copy are removed (Windows Git has some issues with nested repos). 

Imports are declared in the 'import' fact, which must be a single string or an array of strings. The strings must match the following format:

'\[readable/path] AS \[target-name]'

- 'readable/path' must be in the host_reabable_path, which by default includes ../* and ~/.mr/*
- 'target-name' should be a single directory name (no sub/directories), this is the name of the sub-folder in \[active_path]/local-dev.tmp/imp that the imported file/directory on the host will be imported to.

#### Imported Modules

One application of imports is to bundle locally developed Puppet Modules with your project. The 'puppet_modules' fact uses identical syntax to the 'project_repos' fact (see above), and can link to either remote and local paths, (including \[active_path]/import).

As an example:

puppet_modules:
...
../puppet-lib-rhlamp OR vuppet/import/lib-rhlamp AS rhlamp

would attempt to load the module first from a copy on the local file_system (outside of the project folder), and if it didn't exist, would look for a copy in the default active_path that had been imported by an installer.
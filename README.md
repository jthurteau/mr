# Mr
Developer tool for Environment Replication leveraging a Vagrant/Puppet/Fedora stack for VM provisioning.

## Current Status

Mr is being ported from a private 0.x development build to a public open-source 1.x build. 0.x began as a git-gist in early 2019 (https://gist.github.com/jthurteau/3c3d8e15208d93c0cf28cc2148c91b0b), it's undergone heavy development as a practical tool since then but needed drastic refactoring (because I'm really not a Ruby developer).

As of 1.0 (#ef8595a) both RHEL and a fallback strategy to Fedora should be working. Lots of work is still needed but it should be a viable replacement for 0.X provisioners at this point.

For a lighterwight, container based approach check out the [Tm](https://github.com/jthurteau/jthurteau.github.io) Pod VM provisioner (Vagrant/Podman/Alpine stack) bundled in my personal website.

## Getting Started

This documentation covers using Mr to:

 - reproduce a sandbox Virtual Machine (VM) provided with a project
 - make host envionment (e.g. files) available in a sandbox VM 
 - make environment from the sandbox VM available to the host
 - set up a project with an automatically repoducable sandbox VM
 - develop recipes for sandbox VMs that translate into production environments

 If you are looking for common troubleshooting steps, also consult: [Common Issues](https://github.com/jthurteau/mr/wiki/Common-Provisioning-Issues-\(and-solutions\))

### Building a project that uses Mr

*under construction*

#### Core Components 

Mr is broken down into several core components:

- Mr(.rb which drives the "Vuppeteer"), represents the provisioner and the only thing you should need to interact with directly from the Vagrantfile
- VagrantManager and PuppetManager which help negotiate interactions with Vagrant configuration and Puppet configuration
- FileManager, which helps manage host and guest VM files (and limits host file access)
- ElManager, which helps manage guest box identity, networking, registration, etc.

#### Built-in Provisioners

Each is added automatically, as runs :once unless otherwise specified

- mr-install (runs :never)
- mr-uninstall (runs :never)
- puppet-prep
- puppet (runs :once, unless puppet is disabled with 'bypass_puppet' and then it is unavailable)
- puppet-sync
- puppet-reset (runs :never)

- register
- unregister (runs :never and on destroy)
- update_registration (runs :never)
- software_collections (:once only if software collections is configured)
- refresh (runs :never)


## Mr Options

A hash of configuration options can be passed into the inital Mr::vagrant call from the Vagrantfile, these are generally intended to be things that should be disclosed to anyone running the build and not burried in the details of the project recipes. 

Options that can only be set in this way ("Vagrantfile Options"), include:

 - root_path
   - Defaults to '.', being a relative reference to the folder containing the Vagrantfile
   - This sets the "project root" for Mr, which is the base path for all following path calculations
   - This setting cannot traverse up the file tree, and is limited to the folder containing the Vagrantfile and its sub-directories
 - mr_path
   - Defaults to './vuppet', being a relative reference to a peer folder to the Vagrantfile (or root_path if set differently)
   - This sets the "active path" for Mr, which is effectively the default path for all host operations
   - This must be within the 'allowed_read_path'
 - allowed_read_path
   - Defaults to \['../', '~/.mr/'] (relative calculations made on root_path)
   - One (string) or more (array of strings) paths that Mr is allowed to read from
   - Any files to be shared with the sandbox VM should be in the allowed_read_path, otherwise Mr will abort
   - In addition to these read paths, when Mr is running as an external provisioner it may read from peer files and folders to the mr.rb (aka the my_path), but it may not share these with the guest VM directly. It may share copies of these files placed in the allowed_write_path.
 - allowed_write_path
   - Defaults to allow './vuppet' (i.e. the mr_path, the active_path)
   - One (string) or more (array of strings) paths that Mr is allowed to write to
   - Any files to be altered on the host should be in the allowed_write_path, otherwise Mr will abort
   - Mr does not police the guest VM's access to files mounted via Vagrant
   - see 'safe_mount' for an option to limit guest access
 - target_manifest
   - File in the active_path to write a single compiled Puppet manifest (.pp) representing what will be sent to the sandbox VM
   - defaults to './vuppet/local-dev.pp'
   - must be in the allowed_write_path
 - localize_token
   - String prefix for files not intended to be commited back to the project's repo
   - Defaults to 'local-dev.', e.g. local-dev.pp is the default manifest built to direct Puppet how to provision the sandbox VM, but that file may contain local and/or sensitive values so it is excluded from the repo
   - Mr provides a sample .gitignore, but configuring the project repo is left up to the developer
 - override_token
   - String prefix for files that start with the 'localize_token', but are "samples" intended to be included in the repo
   - Defaults to 'example.', e.g. local-dev.example.vuppeteer.yaml is an example of what you might put into the local copy of local-dev.vuppeteer.yaml file.
   - Mr provides a sample .gitignore, but configuring the project repo is left up to the developer
 - load_local_facts
   - String or Boolean indicating whether or not to use a "local facts file" as part of the build process.
   - Defaults to './vuppet/local-dev.vuppeteer.yaml', assuming the localize_token is 'local-dev.' and active_path is './vuppet'
   - must be in allowed_read_path
 - *future support*
   - vuppeteers
     - list of paths to recognized Mr scripts (e.g. this can be the vuppeteer_order used to find Mr), useful for detecting updates in recipe sources
   - sym_friendly
     - set v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]

Other options can be passed in the Vagrantfile, or set during the initialization process from configuration files. Generally the consideration behind where they should be set hinges on making it clear how the project is built without an overwhelming level of detail up-front. 

 - facts
   - Hash of values constituting parameters to building the sandbox VM, or string name (ommitting the .yaml extension) for the build configuration fact source. 
     - while most other "fact sources" can start with '::' to indicate they should be aquired from a facet of the already loaded build configuration facts, this fact source must resolve to a file (it may not begin with '::'). It may include '::' after the file name to limit the scope of the build configuration facts within the loaded file.
   - These values will be directly available to both Mr and Puppet ('puppet_fact_source' changes this behavior)
   - If the value is a hash, the default configuration file (\[active_path]/vuppeteer.yaml) is still loaded if it exists
   - additional values from other .yaml files in the active path are also be merged into the facts depending on configuration
 - require
   - Array of facts that must be defined (non-nil), otherwise the build to be halted during validation
   - Each item may be 
     - a String, indicating the fact must not be 'nil' (undefined/null) or 
     - a Hash evaluated as if passed to 'assert' below, or 
     - an array of one or more strings "dig" through facts, followed by an optional hash or symbol for value testing (similar to assert below), otherwise the normal non-nil test is applied
   - See "Build Validity" for information on match_types 
 - assert
   - Hash of facts and matching values that the build must generate, otherwise it will be halted during validation
   - Values associated with each key may be a scalar for exact matching, if the value is a symbol or hash with any symbol keys, Mr will test the value against a "matching" algorithm (See "Build Validity").
   - Shorthand for a common case of the above "require" option
 - generated
   - Hash describing facts to be generated (e.g. by randomized methods)
   - See "Procedural Facts" for the configuration of these values
 - stack
   - List of token strings indicating what recipes Mr should look for in the active path. This informs both the process of building a sandbox VM and the process of installing a self-provisioning copy of Mr into a project
   - It is generally recommended to publish the stack for your project in the Vagrantfile options, but it may be declared in the project build configurationanywhere in the fact building process
 - safe_mount
   - #TODO future feature to mount guest mounts as read_only
 - load_developer_facts
   - String or Boolean indicating whether or not to use a "developer facts file" as part of the build process.
   - Defaults to '~/.mr/developer.yaml'
   - Cannot be accessed if not in allowed_read_path
  - load_instance_facts, indicates if Mr should keep a special set of peristent facts created on the initial `vagrant up` and destroyed on `vagrant destroy`
    - defaults to true and is needed to support various features like random values and bandwidth throttling
 - load_stack_facts
   - Boolean, Defaults to true, set to false to disable loading any .yaml files from the '(\*.)facts' folders of active_path and/or "my_path". 
 - disable_hiera
   - Boolean, Defaults to false, set to true to disable Hiera for Puppet and any configuration from .yaml files from the '(\*.)hiera' folders of the active_path and/or "my_path". This also prevents Hiera from blocking matching .pp configuration files in the '*manifests' folders. See "Build Maturity" for more information.
 - verbose
   - increases a variety of error outputs, and tends to increase verbosity to sub-components (e.g. Puppet)
 - debug
   - turns on verbosity and prevents a variety of outputs from being buffered by triggers 

## Mr Configuration Sources

All of the components of Mr (Vuppeteer, FileManager, VagrantManager, PuppetManager, ElManager) are designed to be configurable. Except for FileManager, the components take some or all configuration from optional YAML files distributed with a project. FileManager configuration is only possible in Vagrantfile Options.

In a future version, they will also be configurable to allow for single configfile support by specifying paths within YAML files as the configuration source.

Mr's default configuration uses several rules for determining where to look for configuration:

Vuppeteer (loading the core project build facts) looks for local-dev.vuppeteer.yaml, and then vuppeteer.yaml in the active_path only. It can be configured not to use "local facts" by setting the Vagrantfile option "load_local_facts" to false (which applies to any local-dev.\*.yaml file source). It can also be configured to look for a different source file in the active path by specifying a string for the "facts" Vagrantfile option. 

In a future version, a new separate option will allow specifying a different source file along with providing a hash of facts to the "facts" option.

Vuppeteer configuration must come from a file in the active_path (not the my_path of external provisioners), but it may traverse to a specific value in the YAML using the '::' operator, e.g.:

options = {facts: 'project::php::widget'}

Would map to \[php]\[widget] in vuppet/project.yaml

The configuration sources for VagrantManager (defaults to vagrant.yaml), PuppetManager (defaults to puppet.yaml), and ElManager (defaults to el.yaml) will load from the active_path if available, and fallback to a copy provided by the external provisioner if they are not present in active_path. This fallback behavior is only available when Mr is running as an external provisioner. An installed provisioner will not look outside of active_path for any facts.

In a future version these managers will be configurable to allow specifying a fact source to traverse within the loaded project/local facts, and also specify alternative file sources in the active_path.

## Mr Stack

The "stack" is a Mr feature that allows you to automatically apply a variety of recipes to your build. Facts, manifests and Hiera data to be processed by puppet along with Bash scripts and templates are the core building blocks for these recipes. Mr layers recipes in a flexible manner, and can help install the recipes across projects.

Stacks represent project technology dependencies. Breaking up projects in this way allows for flexible and re-usable building blocks that dove-tail into Puppet's infrastructure. Each entry in the stack provides solution "recipes" for resolving a build dependency which may be solved solely by the stack's recipes co-operatively with other stack recipes, including the recipes unique to your project or provided locally by the person using the project.

Mr's stack is just an array of strings in the project configuration, and the strings are "tags" grouping recipe files. Using the 'apache' tag instructs Mr to apply any "apache" recipes it finds: /vuppet/facts/apache.yaml, /vuppet/facts/apache/hosts.yaml, /vuppet/hiera/apache.yaml, etc.

Mr layers stack entries in the following priority (it will use the first match it finds and skip any that follow):

\[active_path]/local-dev.\[type-folder]/\[\*matches]
\[active_path]/\[type-folder]/\[\*matches]
\[active_path]/global.\[type-folder]/\[\*matches] (when Mr is running internally only)
\[my_path]/\[type-folder]/\[\*matches] (when Mr is running externally only)

As will be detailed later, the "Install Process" copies the "external" recipes to the "global" recipes when creating an embedded provisioner, so only one of these two types are available depending on if an external copy of Mr, or an internal (embedded) copy is managing the current Vagrant execution.

The behavior for \[\*matches] varries slightly depending on the type of recipe file.

### Stack Matching Behavior for "Auto-included" Puppet Files

For facts, manifests, and hiera (puppet files) stacks matches are on the direct decendents of the type-folder and includes the matching direct decendent file, or direct decendent folder and all files under it. These files are automatically included in the Puppet Apply process for provisioning a machine, they are "auto-included". The exception to this auto-inclusion process is when Hiera is enabled (the default setting), Mr will skip "manifests" that exactly match an available "hiera" file. It ignores both the \[type-folder]\ portion of the path and the file extension, .pp for manifest and .yaml for hiera. Conversely, if Hiera is disabled then all "hiera" files are ignored allowing the blocked manifests through.

e.g. 
\[active_path]/local-dev.hiera/apache.yaml would block

\[active_path]/manifests/apache.pp

but not 
\[active_path]/manifests/apache/certs.pp

The rationale and applications of this "blocking" behavior are detailed in "Build Maturity"

### Stack Matching Behavior for Other Files

Bash scripts and templates are not "auto-included" in the same way that Puppet Files are. They may be referenced by Puppet manifests. Mr uses these files based on its own processes and provisioners, and can use them in custom provisioners passed down from the Vagrantfile. This includes mechanisms for triggers detailed in "Stack Triggers"

For bash and template folders (primarily used by Mr, but may be referenced by Puppet), the direct file decendents of the type-folder are implicitly included during install (see also "Provisioner Installation: Mirroring"). Sub-folders of the bash and template type-folders are only installed if they match a stack fact (as described above for Puppet Files).

### Local Stack

Mr can also mix-in stack facts tags on initialization options. Unless configured otherwise, it automatically adds project and application based tags, and allows individual developers to layer tags to local copies of a project.

There are a variety of ways stack tags can be cusomized to futher refine the behavior, and these are documented in 'Stack Tag Syntax'

### Build Validity

### Procedural Facts

Mr supports several types of Procedural build facts, the first is "requirements" which are facts that must be defined and non-nil after all buils facts have been loaded.

The "requirements" option passed to Mr may be a string, or an array of strings. Any non-nil value will satify the requirement.

More robust fact validation is possible using "asserts". The basic syntax of an assert is a hash where the keys match keys in the build facts and the values are literals that match the generated value. If the value is a hash with any symbol keys, it is parsed as a "match config" instead.

Both asserts and requirements support a single string option (for asserts the string is mapped as the required value for the the "project" fact). Aside from that, requirements must be defined as an array (since they accept no value for each required key) and asserts must be defined as a Hash since they expect some match criteria for each key.

Aside from testing requirements and asserts, Mr can also generate facts procedurally using the "generated" option. Generated facts are also passed as a Hash and use the same "match config" syntax to define behavior for procedurally generating facts. The most common example is using generated facts to create a unique random password and other secrets for provisioning applications. Generated facts are stored in the "instance facts" when they are not derived from other project facts in a way that can be reproduced, e.g. random facts are always stored.


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

Entries in the puppet_modules can reference github (public or authenticated via PAT), and gitub enterprise repos. These are handled by Mr by placing them into a gitignored path in the repo (in /vuppet) and then auto-imported along with other repos so there is no need to include them in the 'import' fact, and the 'import' fact does not support URIs directly at this time, only local paths.

## Enterprise Linux Management

Using RHEL as a VM effectively requires access to a software repository for package management and updates. This can be especially important for VirtualBox Guest Plugins, and installing Puppet. Mr can be configured to use a RedHat Developer account (https://developers.redhat.com/), or a local CLS to register the RHEL operating system. For the former, those settings can be baked into the repository if everyone using the code is part of the same organization. For shared (open) code, you'll want to create a RedHat Developer account and store that data in a "developer facts" file which is stored in your user files and not in the repo.

The default setup allows Mr to read from two paths: the relative "../" path from mr.rb which should be the root of your repository, and "~/.mr/" which is an optional folder in your user files. If you don't have this folder, Mr should run fine but many operations including

A sample for this file is available in /vuppet/local-dev.example.mr-developer.yaml

You can create the .mr folder in your "home" directory (e.g. /home/\[username] or C:users\\\[username]) and use the sample to start your 'developer.yaml' file.

To use a RedHat Developer account, uncomment the:

'license_ident: rhel7-dev' line and then also provide 'rhsm_user' and 'rhsm_pass'

For security reasons, a number of the values intended to be stored in the developer facts (developer.yaml) file can ONLY be retrieved from the developer facts file. You can set where a project will look for the developer facts by setting a non-binary value for 'load_developer_facts', but access is still subject to normal restrictions, so it must be in an allowed (read) path(s).


## Project Configuration

### Stack Optional

The 'stack_optional' fact in project configuration can be set to specify any stack base tags (tags with no special syntax below) for Mr to include in an install. These are useful when your project's stack is variable at run-time, or there are stack entries you know some developers will mix-in locally that are not a core part of your build. Mr will install all files for recipes matching the base tags in both the 'stack', and 'stack_optional' facts during a 'mr-install' provision.

### Stack Tag Syntax

There are a variety of ways stack tags can be modified to drive Mr behavior. By default a "tag" is just a string with lower case alpha-numeric characters plus dash and underscore. Mr applies no special meaning to these characters and they match files and folders that exactly equal the string, or match the script upto the first dot (.) in the filename. The tag "apache", matches 'apache.yaml', 'apache.pp', the folder 'apache', 'apache/host.yaml' etc., but not 'apache_hosts.yaml'. These matches apply to any "recipe folder", and Mr will select the first match among the local, project, global, and external recipes (in that order).

Tags that match this default pattern are "base tags", and when determining what files to install, Mr always truncates tags in the stack to a "base tag", remiving any additional syntax. This ensures files related to build a project that using that "stack" are available in cases where someone you are sharing it with has slightly different needs that the stack is designed to handle.

### Project Options

By default, Mr expects a single-VM, project or app based build. If neither the 'project' or 'app' fact are specified it will provision nothing. If multiple VMs are specified, each must be explicitly enabled, otherwise none are provisioned. Mr will only auto-provision one VM and only in a single-VM configuration.

- disabled, the default Mr behavior in a single VM project is enabled, but it can be disabled (for all VMs) by setting the 'disabled' fact. This allows Mr to spin-up, but it will not run any provisioners, triggers, or helpers. Any provisioners defined in the Vagrantfile will still run as if it were a normal Vagrantfile, this setting prevents Mr from attaching to the vagrant object passed to it in the Mr::vagrant call.
- bypass_puppet, instructs Mr to run as normal, except the 'puppet' provisioner will not run. (it will perform 'puppet-prep' as normal however.)
- test_puppet, defaults to false. instructs Mr to build manifests/hiera for puppet when bypass_puppet is true
- standalone, forces single VM mode and further simplifies the logic for the vm_name
- project, forces single VM mode and names the project being managed by Mr, see 'Bundling' for how this manages behavior
- app, forces single VM mode and names the application being managed by Mr, see 'Bundling' for how this manages behavior
- vm_name, forces single VM mode and specifies the exact value for vm_name and attempts to map the vm's configuration to a matching project or app bundled by the provisioner
  - defaults to \[project]\[-suffix] if 'project' is specified, or \[app]\[-suffix] if 'app', otherwise \[suffix]
  - \[-suffix]/\[suffix] is derived from:
    - empty string if fact 'standalone' is true and the project or app name are at least two characters in length
    - otherwise \[-developer]\[-org]\[-box] based on values gathered by the project configuration
    - '-dev' is appended if a developer license is in use
    - if 'generic/X' boxes are used, the 'generic/' portion is omitted, otheriwse slashed in the box name are converted to dashes
    - box always defaults to 'generic/rhelV' when not specified, where V is the EL version.
- vms, a string vm_name, array of vm_name(s) or a hash keyed by vm_name(s). 
  - automatically switches Mr to multi-vm mode unless 'standalone' or 'vm_name' is set
  - in the case of an array, Mr expects a \[vm_name].yaml to exist in the active path for each VM
  - in the case of a hash, each key is the vm_name and the value for each key is a expected to be: string or a hash
    - string values resolve to a yaml file in the same way as vms defined by array
    - hash values are applied as if they were the result of a loading a yaml file
  - the contents of the vm config are layered on top of a copy of the project config that excludes select keys, including:
    - 'enabled', 'project', 'app', 'standalone', 'ignore', 'merge', and any key in the vm config's 'ignore' fact.
    - the contents of the vm's config replace matching keys from the project's config unless the the vm's 'merge' fact alters the merge behavior for that key.
- generated, fact values to be generated by Mr per local instance of a project (see "Mr Options")
- assert, facts that must match a certain value, or the build will be aborted (see "Mr Options")
- require, facts that must exist or match a certain value, of the the build will be aborted (see "Mr Options")
- stack, list of dependencies for Mr to resolve for the project build (see "Mr Options")
- safe_mount #TODO future feature to mount guest mounts as read_only
- load_developer_facts, whether/where to load local developer facts (see "Mr Options"), must be set in Mr Options, or the "local_facts" file.
- load_instance_facts, whether to maintain instance facts (defaults to true, several core features require this, see "Mr Options")
- load_stack_facts, whether to load stack facts (see "Mr Options")
- disable_hiera, whether to use Hiera for Puppet (see "Mr Options")
- verbose, increases error outputs generally (see "Mr Options")
- debug, sets 'verbose' true, enabled additional output, and prevents a variety of outputs from being buffered (see "Mr Options")
- software_collection, enables use of Software Collections and optionally sets a source
- sc_repos, sets a list of repos to enable for software_collections
- license_ident, string or hash configuring how ElManager will handle VMs, including box_source, registration, and various OS related environment settings. strings are used as a lookup for idents defined in el.yaml
- import, list of host files to mirror to the installed provisioner (see "Provisioner Installation")
- puppet_modules, list of puppet modules the provisioner will use, and where to get them (see "Provisioner Installation")
- install_files, list of Mr files to copy into the installed provisioner (see "Provisioner Installation")
- install_global_files, list of Mr files to copy into the installed provisioner as "global"files (see "Provisioner Installation")
- project_repos, list of host and remote files to mirror into the local provisioner (See "Project Repos")
- helpers, list of helper provisioners to add automatically, unlike some most other facts, the helpers from different sources are set to "merge"  by default.
- guest_throttle, bandwidth limit shared across all VMs. this feature only works when load_instance_facts is true (the default value)
  - note that this can be dicey since since detection of existing throttle settings isn't resolved yet. If the initual `vagrant up` fails before the VM is created you may need to remove "vbox_throttle" from local-dev.instance.yaml since Mr thinks the bandwidth group exists when it does not.
- puppet_fact_source, source to load facts for PuppetManager to use in puppet_apply, defaults to '::' which is 
- puppet_config_source, source to load configuration for PuppetManager, defaults to puppet.yaml
- vagrant_config_source, source to load configuration for VagrantManager, defaults to vagrant.yaml
- el_config_source, source to load configuration for VagrantManager, defaults to el.yaml
- el_license, a set, or calculated and stored instance fact to ensure that once a VM has been built changes to the build facts doesn't result in a mis-match
- box_source, specifies a box to use for the build, if this is set it is recommended to also set el_version
- default_to_rhel, defaults to true. fedora is used if false and no box_source is set
- el_version, the version of EL for the build, only set this to force and avoid autodetection
- developer_el_license,
- license_important, adjusts the current license negotiation algorythm to favor project values over developer values

    'git_developer','ghc_developer','ghe_developer',
    'ghc_pat',
    'ghe_pat','ghe_host',
    'rhsm_user','rhsm_pass','rhsm_org', 'rhsm_key', 'rhsm_host',
---future features---
- license, one or more license ident strings the project supports, in general order of preference
- developer_license, one or more license ident strings the developer prefers, in general order of preference
- el_min_version, specifies the default minimum version of el the project will support, defaults to 7. If set, any license candidate must provide version data and be meet the minimum to be considered
- licenses and developer_licenses,
  - licenses is normally pulled from el.yaml (or local-dev.el.yaml when present), but may also be specified in build facts. This data deep merged in the following order local-dev.build.yaml > local-dev.el.yaml > build.yaml > el.yaml


#### Bundling

By default, Mr expects a 'project' or 'app' (application) to be specified. These facts each add a stack entry ('project_\[name] and 'app_\[name]' respetively) which is considered to be the "driver" for the build, so it is added at the highest level of priority after the project_config. It looks for a project first, then an app in order to determine the "primary VM". It is valid to specify both, and aside from determining the name of the primary VM, they layer as normal stack entries.

Specifying the 'project' or 'app' directive is just a simple way to attach the project configuration to a single VM.

The only real difference in 'projects' and 'apps' are conventions in the way they are designed. Apps are simpler builds that assume a one-app-to-vm-to-build model. They may muddle the configuration for what is being built by Mr, Vagrant, Puppet, etc because the build has a narrow focus. This makes for effective prototyping and an easy to share a build, but it bypasses the additional work needed to more portable projects.

A code repo may bundle multiple apps in the Mr provisoiner that are easily swapped out with some basic tooling or configuration. All you have to do is tell Mr to build a different 'app'. This doesn't solve larger concerns about modularity, reusability, portability, etc.

Projects on the other hand are designed with a more modular approach that isolates components' configuration to separate configuration files or facets and layers them on a more generalized project configuration. The Mr provisoiner might still reference a default 'project' (which is a single VM build), but it can just as easily swap that out for different bundled projects, or map VMs to a bundled project to enable more advanced provisioning and deployment workflows. 

The configuration for a 'project' should be modeled in a way that makes the components easy to merge into other projects or replicate in a non-Mr-Vagrant-Puppet environments. 

App builds are more of a quick and dirty tinkering/development/learning tool, while Project builds better leverage Mr's Environment Replication and Insulation capabilities.



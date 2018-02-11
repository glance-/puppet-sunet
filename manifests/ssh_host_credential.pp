define sunet::ssh_host_credential(
      $hostname    = 'localhost',
      $username    = 'root',
      $group       = 'root',
      $id          = 'default',
      $manage_user = true,
      $manage_key  = true,
      $revision    = 'master',
      $ensure      = 'present',
      $ssh_privkey = undef
) {
   if ($manage_user) {
      ensure_resource('group',"${group}")
      sunet::system_user { "${username}":
         username  => "${username}",
         group     => "${group}"
      }
   }
   $ssh_home = $username ? {
      'root'    => '/root/.ssh',
      default   => "/home/${username}/.ssh"
   }
   file { "${ssh_home}":
      ensure    => directory,
      mode      => '0700',
      owner     => "${username}",
      group     => "${group}"
   } ->
   augeas {"ssh_config_set_host_identity":
      incl    => "${ssh_home}/config",
      lens    => 'Ssh.lns',
      changes => [
         "set /files${ssh_home}/config/Host ${hostname}",
         "set /files${ssh_home}/config/Host[.='${hostname}']/IdentityFile ${ssh_home}/${id}"
      ]
   } ->
   sunet::ssh_keyscan::host {$hostname: }
   if ($ssh_privkey) {
      file { "${ssh_home}/${id}":
         content => inline_template('<%= @ssh_privkey %>')
      }
   } elsif ($manage_key) {
      exec { "${title}-ssh-keygen":
         command => "ssh-keygen -N '' -C '${username}@${::fqdn}' -f '${ssh_home}/${id}' -t ed25519",
         user    => "${username}",
         onlyif  => "test ! -f ${ssh_home}/${id}"
      }
   }
}
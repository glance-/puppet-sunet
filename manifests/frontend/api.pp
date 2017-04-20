define sunet::frontend::haproxy(
  $username = 'sunetfrontend',
  $group    = 'sunetfrontend',
  $basedir  = '/opt/frontend/api',
)
{
  ensure_resource('sunet::system_user', $username, {
    username => $username,
    group    => $group,
  })

  exec { 'haproxy_mkdir':
    command => "/bin/mkdir -p ${basedir}",
    unless  => "/usr/bin/test -d ${basedir}",
  } ->
  file {
    "$basedir/backends":
      ensure  => 'directory',
      mode    => '0770',
      group   => $group,
      require => Sunet::System_user[$username],
      ;
  }
  sunet::docker_run { "${name}_api":
    image    => 'docker.sunet.se/sunetfrontend-api',
    imagetag => 'latest',  # XXX change to 'stable',
    net      => 'host',
    volumes  => ["${basedir}/backends:/backends",
                 '/dev/log:/dev/log',
                 ],
    require  => [File["$basedir/backends"]],
  }
}
